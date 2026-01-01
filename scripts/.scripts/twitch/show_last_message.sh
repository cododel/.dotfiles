LAST_MESSAGE=$(curl --silent http://localhost:3999 || echo "Error")

if [ "$LAST_MESSAGE" = "Error" ];
  then
  exit 0
fi

echo "  Twitch ➜  $LAST_MESSAGE"
