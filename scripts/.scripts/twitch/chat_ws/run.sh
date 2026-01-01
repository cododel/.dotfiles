export TOKEN="$(twitch token -u -s 'chat:read chat:edit' 2>&1 >/dev/null | awk '/User Access Token:/ {print $2}' OFS=': ' FS=': ')"
npm run start
