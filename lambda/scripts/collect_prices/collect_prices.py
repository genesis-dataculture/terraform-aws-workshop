import json
import urllib.request
import boto3

from datetime import datetime

def lambda_handler(event, context):
    tickers = ["bitcoin", "ethereum"]
    s3_resource = boto3.resource("s3")
    bucket_name = 'raw-data-bucket-genesis-lmeazzini'
    for ticker in tickers:
        url = f'https://api.coingecko.com/api/v3/simple/price?ids={ticker}&vs_currencies=usd'
        try:
            with urllib.request.urlopen(url) as response:
                data = json.loads(response.read().decode())
                
                price = data.get(ticker, {}).get('usd', 'Price not available')
                price_dict = {
                    "ticker": ticker,
                    "timestamp": datetime.now().isoformat(), 
                    "price": price,
                }
                print(price)
                
                obj = s3_resource.Object(bucket_name, f'{ticker}/{datetime.now()}.json')
                obj.put(
                    Body=(bytes(json.dumps(price_dict).encode('UTF-8')))
                )
                
                
        except Exception as e:
            print(f"failed to get {ticker} price: {e}")

