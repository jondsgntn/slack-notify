# slack-notify

This is the early stage of a ruby script for monitoring page status

It reads from a list of websites and, if one returns a 40x or 50x error, it sends a notification to Slack

If a page returns an error 5 times in a row, a text message is sent to a specified phone number
