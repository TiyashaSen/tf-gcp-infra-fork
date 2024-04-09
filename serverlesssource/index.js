const functions = require("@google-cloud/functions-framework");
const dotenv = require("dotenv");

const mailgun = require("mailgun-js");
const Sequelize = require("sequelize");

let API_KEY = "63879c1c184af6eb81dd56e1d5dc4c73-309b0ef4-926300ae";
let DOMAIN = "mailgun.cloud-cssye.me";
const mg = mailgun({ apiKey: API_KEY, domain: DOMAIN });
dotenv.config();

functions.cloudEvent("helloPubSub", async (cloudEvent) => {
  const base64name = cloudEvent.data.message.data;

  const name = base64name
    ? Buffer.from(base64name, "base64").toString()
    : "World";
  const jsonData = JSON.parse(name);
  console.log(jsonData);

  try {
    const sequelize = new Sequelize(
      process.env.PSQL_DATABASE,
      process.env.PSQL_USERNAME,
      process.env.PSQL_PASSWORD,
      {
        host: process.env.PSQL_HOSTNAME,
        dialect: "postgres",
      }
    );
    await sequelize.authenticate();
    console.log("Database connected successfully.");
    const res = await sequelize.query(
      `UPDATE "users" SET "emailSentTime" = NOW(), "tokenGenerated" = '${jsonData.tokenGenerated}' WHERE "username" = '${jsonData.username}'`,
      { type: Sequelize.QueryTypes.UPDATE }
    );
    await sequelize.close();
  } catch (error) {
    console.log(error);
  }

  const tokenGenerator = "https://cloud-cssye.me/verifyUser?tokenValue=";
  const tokenValue = jsonData.tokenGenerated;
  const newUrl = tokenGenerator + tokenValue;

  // Extract data for sending email
  const sender_email = "email@mailgun.cloud-cssye.me";
  const receiver_email = jsonData.username;
  const email_subject = "Action Required: Verify Your Email Address";
  const email_body = `<p>Click <a href="${newUrl}">here</a> to verify your email.</p>`;

  // Call the sendMail function
  try {
    await sendMail(sender_email, receiver_email, email_subject, email_body);
  } catch (error) {
    console.log(error);
  }
});

const sendMail = async (
  sender_email,
  receiver_email,
  email_subject,
  email_body
) => {
  const data = {
    from: sender_email,
    to: receiver_email,
    subject: email_subject,
    text: email_body,
  };

  try {
    const emailMessage = await mg.messages().send(data);
    console.log(emailMessage);
  } catch (error) {
    console.log(error);
  }
};
