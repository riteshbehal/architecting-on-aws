from amazondax import AmazonDaxClient
import boto3
import time

client = AmazonDaxClient(
    region_name="us-east-1",
    endpoints=["dax://products-cluster.vrl0te.dax-clusters.us-east-1.amazonaws.com"]
)

start = time.perf_counter()

for i in range(100):
    client.get_item(
        TableName="Products",
        Key={
            "ProductID": {"S": "P001"}
        }
    )

end = time.perf_counter()

print(f"DAX Time: {end-start:.4f} seconds")