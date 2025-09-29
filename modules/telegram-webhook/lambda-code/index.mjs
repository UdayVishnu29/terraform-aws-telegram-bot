import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;
const sqsClient = new SQSClient({ region: "us-east-1" }); // SQS queue's region

export const handler = async (event) => {
  try {
    let update = JSON.parse(event.body);
    console.log(
      "✅ Telegram update received:",
      JSON.stringify(update, null, 2)
    );

    const chatId = update.message?.chat?.id;
    const userText = update.message?.text;

    if (chatId && userText) {
      const payload = { chat_id: chatId, user_text: userText };

      const command = new SendMessageCommand({
        QueueUrl: SQS_QUEUE_URL,
        MessageBody: JSON.stringify(payload),
      });

      console.log(`🚀 Sending message to SQS...`);
      await sqsClient.send(command);
    }

    return { statusCode: 200, body: "ok" };
  } catch (err) {
    console.error("❌ ERROR in Webhook Lambda:", err);
    return { statusCode: 500, body: "error" };
  }
};
