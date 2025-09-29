import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from "@aws-sdk/client-bedrock-runtime";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
} from "@aws-sdk/lib-dynamodb";

// --- Environment Variables ---
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const BEDROCK_MODEL_ID = process.env.BEDROCK_MODEL_ID;
const DYNAMODB_TABLE_NAME = process.env.DYNAMODB_TABLE_NAME;
const AWS_REGION = "us-east-1";

// --- AWS Clients ---
const bedrockClient = new BedrockRuntimeClient({ region: AWS_REGION });
const ddbClient = new DynamoDBClient({ region: AWS_REGION });
const ddbDocClient = DynamoDBDocumentClient.from(ddbClient);

// --- Helper Functions ---

async function getChatHistory(chatId) {
  const command = new GetCommand({
    TableName: DYNAMODB_TABLE_NAME,
    Key: { chat_id: chatId },
  });
  try {
    const response = await ddbDocClient.send(command);
    return response.Item?.history || []; // Return history array or an empty array if none exists
  } catch (err) {
    console.error("Error getting chat history:", err);
    return [];
  }
}

async function saveChatHistory(chatId, history) {
  // Keep only the last 4 turns (8 messages) for memory
  const trimmedHistory = history.slice(-8);
  // Set the Time-to-Live (TTL) for 24 hours from now
  const ttl = Math.floor(Date.now() / 1000) + 86400; // 86400 seconds in a day

  const command = new PutCommand({
    TableName: DYNAMODB_TABLE_NAME,
    Item: {
      chat_id: chatId,
      history: trimmedHistory,
      ttl: ttl,
    },
  });
  try {
    await ddbDocClient.send(command);
  } catch (err) {
    console.error("Error saving chat history:", err);
  }
}

async function sendTelegramReply(chatId, text) {
  // ... (This function is unchanged)
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  const payload = { chat_id: chatId, text: text };
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok)
    console.error("Error sending message to Telegram:", await response.json());
  else console.log("✅ Successfully sent reply to Telegram.");
}

// --- Main Handler ---

export const handler = async (event) => {
  for (const record of event.Records) {
    try {
      const messagePayload = JSON.parse(record.body);
      const chatId = messagePayload.chat_id;
      const userText = messagePayload.user_text;

      console.log(`Processing message for chat_id: ${chatId}`);

      // 1. Get previous chat history
      const history = await getChatHistory(chatId);

      // 2. Format the history and instructions into the prompt
      const instructions = `You are a helpful and friendly AI assistant.
      - Your goal is to provide useful and factual answers.
      - IMPORTANT: You must never give medical advice. If asked, politely decline and advise the user to consult a medical professional.
      - If the user's question has small grammatical errors, interpret their likely intent and answer the corrected question.
      - NEW RULE: If a user asks personal questions, tries to form a personal relationship, or says things like "I love you," you must politely maintain your persona as an AI. Remind them that you are a language model and cannot have feelings or personal relationships, but that you are happy to help with informational questions. Do not use the phrase "I can't let people know about my existence."`;

      let historyText = history
        .map((turn) => `${turn.role}: ${turn.content}`)
        .join("\n");
      const formattedPrompt = `${instructions}\n\n${historyText}\nQuestion: ${userText}\nAnswer:`;

      const prompt = {
        inputText: formattedPrompt /* ... textGenerationConfig ... */,
      };

      // 3. Invoke Bedrock
      const command = new InvokeModelCommand({
        modelId: BEDROCK_MODEL_ID,
        contentType: "application/json",
        accept: "application/json",
        body: new TextEncoder().encode(JSON.stringify(prompt)),
      });
      const bedrockResponse = await bedrockClient.send(command);
      const responseBody = bedrockResponse.body.transformToString("utf-8");
      const parsedResponse = JSON.parse(responseBody);
      const botReply = parsedResponse.results[0].outputText.trim();

      console.log("Received reply from Bedrock:", botReply);

      // 4. Send the reply to the user
      await sendTelegramReply(chatId, botReply);

      // 5. Update and save the new chat history
      const updatedHistory = [
        ...history,
        { role: "user", content: userText },
        { role: "assistant", content: botReply },
      ];
      await saveChatHistory(chatId, updatedHistory);
    } catch (err) {
      console.error("❌ ERROR processing SQS record:", err);
    }
  }
};
