import boto3
import os
import json
import time


def wait_for_healthy_targets(elbv2, target_group_arn, expected_count, timeout_seconds=240):
    deadline = time.time() + timeout_seconds

    while time.time() < deadline:
        response = elbv2.describe_target_health(TargetGroupArn=target_group_arn)
        healthy_targets = [
            target
            for target in response["TargetHealthDescriptions"]
            if target["TargetHealth"]["State"] == "healthy"
        ]

        print(f"Healthy DR targets: {len(healthy_targets)}/{expected_count}")
        if len(healthy_targets) >= expected_count:
            return

        time.sleep(15)

    raise TimeoutError("Timed out waiting for DR targets to become healthy")

def lambda_handler(event, context):
    # Log the received event
    print(f"Received event: {json.dumps(event)}")

    # Extract SNS message
    message = event["Records"][0]["Sns"]["Message"]
    print(f"SNS message: {message}")

    # Configuration from environment variables
    domain_name = os.environ["DOMAIN_NAME"]
    hosted_zone_id = os.environ["HOSTED_ZONE_ID"]
    dr_alb_dns = os.environ["DR_ALB_DNS"]
    dr_alb_zone_id = os.environ["DR_ALB_ZONE_ID"]
    dr_target_group_arn = os.environ["DR_TARGET_GROUP_ARN"]
    primary_asg_name = os.environ["PRIMARY_ASG_NAME"]
    dr_asg_name = os.environ["DR_ASG_NAME"]
    primary_region = os.environ["PRIMARY_REGION"]
    dr_region = os.environ["DR_REGION"]
    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]

    # 1. Scale up DR Auto Scaling Group
    dr_autoscaling = boto3.client("autoscaling", region_name=dr_region)
    try:
        response = dr_autoscaling.update_auto_scaling_group(
            AutoScalingGroupName=dr_asg_name,
            MinSize=2,
            DesiredCapacity=2
        )
        print(f"DR ASG scaled up: {response}")
    except Exception as e:
        print(f"Failed to scale DR ASG: {e}")
        raise

    # 2. Wait until the DR ALB has healthy targets before moving DNS.
    elbv2 = boto3.client("elbv2", region_name=dr_region)
    wait_for_healthy_targets(elbv2, dr_target_group_arn, expected_count=2)

    # 3. Update Route 53 record to point to DR ALB
    route53 = boto3.client("route53")
    try:
        response = route53.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": domain_name,
                            "Type": "A",
                            "AliasTarget": {
                                "HostedZoneId": dr_alb_zone_id,
                                "DNSName": f"dualstack.{dr_alb_dns}",
                                "EvaluateTargetHealth": True
                            }
                        }
                    }
                ]
            }
        )
        print(f"Route 53 updated: {response}")
    except Exception as e:
        print(f"Failed to update Route 53: {e}")
        raise

    # 4. Scale down primary ASG to 0
    primary_autoscaling = boto3.client("autoscaling", region_name=primary_region)
    try:
        response = primary_autoscaling.update_auto_scaling_group(
            AutoScalingGroupName=primary_asg_name,
            MinSize=0,
            DesiredCapacity=0
        )
        print(f"Primary ASG scaled down: {response}")
    except Exception as e:
        print(f"Failed to scale primary ASG: {e}")
        raise

    # 5. Send success notification
    sns = boto3.client("sns", region_name=os.environ["AWS_REGION"])
    try:
        response = sns.publish(
            TopicArn=sns_topic_arn,
            Subject="Disaster Recovery Failover Completed",
            Message="Failover to DR region has been successfully executed."
        )
        print(f"SNS notification sent: {response}")
    except Exception as e:
        print(f"Failed to send SNS notification: {e}")

    return {
        'statusCode': 200,
        'body': json.dumps('Failover completed successfully')
    }
