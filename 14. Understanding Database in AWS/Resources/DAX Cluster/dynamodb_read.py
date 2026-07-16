import boto3
import time

dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table = dynamodb.Table("Products")

start = time.perf_counter()

for i in range(100):
    table.get_item(
        Key={"ProductID": "P001"}
    )

end = time.perf_counter()

print(f"DynamoDB Time: {end-start:.4f} seconds")