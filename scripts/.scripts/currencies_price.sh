API_KEY="31d076419b75a579107868046c8eef885b6f63ccf6773dc00e6b10bbb5a30c3d"
FROM="BTC,ETH,MATIC,SAND,USD"
TO="USD,RUB"
BASE_URL="https://min-api.cryptocompare.com/data"


RESPONSE=$(curl --silent "$BASE_URL/pricemulti?fsyms=$FROM&tsyms=$TO&api_key=$API_KEY")

echo $RESPONSE | jq '{
  "BTC": "\(.BTC.USD)$",
  "ETH": "\(.ETH.USD)$", 
  "MATIC": "\(.MATIC.USD)$",
  "SAND": "\(.SAND.USD)$",
  "USD": "\(.USD.RUB)₽" 
}'
