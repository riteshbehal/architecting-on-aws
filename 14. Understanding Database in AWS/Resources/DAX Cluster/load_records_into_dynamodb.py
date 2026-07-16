import pandas as pd
import boto3
from decimal import Decimal

TABLE_NAME = "Products"
REGION = "<YOUR_REGION>" 
EXCEL_FILE = "<SAMPLE_EXCEL_FILE_PATH>"  

df = pd.read_excel(EXCEL_FILE)

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)

with table.batch_writer() as batch:
    for _, row in df.iterrows():
        item = {
            "ProductID": str(row["ProductID"]),
            "ProductName": str(row["ProductName"]),
            "Category": str(row["Category"]),
            "Price": Decimal(str(row["Price"])),
            "Stock": Decimal(str(row["Stock"]))
        }
        batch.put_item(Item=item)

print("Upload complete.")