const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const cors = require("cors");

initializeApp();

const corsHandler = cors({
  origin: true,
  methods: ["POST", "OPTIONS"],
  allowedHeaders: ["Authorization", "Content-Type"],
  preflightContinue: true,
});

const MAX_MESSAGE_LENGTH = 10000;
const MAX_HISTORY_MESSAGES = 20;
const MAX_HISTORY_MESSAGE_LENGTH = 4000;

function normalizeHistory(history) {
  if (history === undefined) {
    return [];
  }
  if (!Array.isArray(history) || history.length > MAX_HISTORY_MESSAGES) {
    throw new TypeError("history must be an array of at most 20 messages.");
  }

  return history.map((entry) => {
    if (
      entry === null ||
      typeof entry !== "object" ||
      !["user", "model"].includes(entry.role) ||
      typeof entry.text !== "string" ||
      entry.text.length > MAX_HISTORY_MESSAGE_LENGTH
    ) {
      throw new TypeError("Each history item must contain a valid role and text.");
    }

    return {
      role: entry.role,
      parts: [{ text: entry.text }],
    };
  });
}

exports.geminiChat = onRequest(async (req, res) => {
  try {
    await new Promise((resolve, reject) => {
      corsHandler(req, res, (error) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.set("Allow", "POST, OPTIONS").status(405).json({
        error: "Method not allowed.",
      });
      return;
    }

    const authorization = req.get("Authorization") ?? "";
    const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
    if (!tokenMatch) {
      res.status(401).json({ error: "Authentication is required." });
      return;
    }

    let decodedToken;
    try {
      decodedToken = await getAuth().verifyIdToken(tokenMatch[1]);
    } catch {
      res.status(401).json({ error: "Invalid authentication token." });
      return;
    }

    const adminSnapshot = await getFirestore()
      .collection("admins")
      .doc(decodedToken.uid)
      .get();
    const adminProfile = adminSnapshot.data();
    if (
      !adminSnapshot.exists ||
      adminProfile?.role !== "admin" ||
      adminProfile?.estadoActivo !== true
    ) {
      res.status(403).json({ error: "Administrator access is required." });
      return;
    }

    const { message, history } = req.body ?? {};
    if (
      typeof message !== "string" ||
      message.trim().length === 0 ||
      message.length > MAX_MESSAGE_LENGTH
    ) {
      res.status(400).json({
        error: `message must contain 1 to ${MAX_MESSAGE_LENGTH} characters.`,
      });
      return;
    }

    let normalizedHistory;
    try {
      normalizedHistory = normalizeHistory(history);
    } catch (error) {
      res.status(400).json({ error: error.message });
      return;
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured.");
      res.status(500).json({ error: "The AI service is not configured." });
      return;
    }

    const generativeAI = new GoogleGenerativeAI(apiKey);
    const model = generativeAI.getGenerativeModel({ model: "gemini-2.0-flash" });
    const chat = model.startChat({ history: normalizedHistory });
    const result = await chat.sendMessage(message.trim());
    const reply = result.response.text();

    if (!reply.trim()) {
      res.status(502).json({ error: "The AI service returned an empty response." });
      return;
    }

    res.status(200).json({ reply, timestamp: Date.now() });
  } catch (error) {
    console.error("geminiChat request failed:", error);
    res.status(500).json({ error: "The AI request could not be completed." });
  }
});

exports.deactivateSellerPublications = onDocumentUpdated(
  {
    document: "users/{userId}",
    retry: true,
    timeoutSeconds: 540,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const userId = event.params.userId;
    if (
      before?.estadoActivo !== true ||
      after?.estadoActivo !== false ||
      after?.publicationCascadePending !== true
    ) {
      return;
    }

    const db = getFirestore();
    const userRef = db.collection("users").doc(userId);
    let lastDocument = null;

    while (true) {
      const currentUser = await userRef.get();
      const currentData = currentUser.data();
      if (
        !currentUser.exists ||
        currentData?.estadoActivo !== false ||
        currentData?.publicationCascadePending !== true
      ) {
        return;
      }

      let query = db
        .collection("publicaciones")
        .where("userId", "==", userId)
        .limit(450);
      if (lastDocument) {
        query = query.startAfter(lastDocument);
      }
      const page = await query.get();
      if (page.empty) {
        break;
      }

      const batch = db.batch();
      let writes = 0;
      for (const publication of page.docs) {
        if (publication.data().estadoActivo !== false) {
          batch.update(publication.ref, { estadoActivo: false });
          writes += 1;
        }
      }
      if (writes > 0) {
        await batch.commit();
      }

      lastDocument = page.docs[page.docs.length - 1];
      if (page.size < 450) {
        break;
      }
    }

    await db.runTransaction(async (transaction) => {
      const currentUser = await transaction.get(userRef);
      const currentData = currentUser.data();
      if (
        currentUser.exists &&
        currentData?.estadoActivo === false &&
        currentData?.publicationCascadePending === true
      ) {
        transaction.update(userRef, { publicationCascadePending: false });
      }
    });
  },
);
