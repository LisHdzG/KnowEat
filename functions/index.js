const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const openaiKey = defineSecret("OPENAI_API_KEY");

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";
const MODEL = "gpt-4o";

const ALLERGEN_IDS = [
  "gluten", "crustaceans", "eggs", "fish", "peanuts",
  "soy", "dairy", "tree_nuts", "celery", "mustard",
  "sesame", "sulfites", "lupins", "mollusks",
];
const INTOLERANCE_IDS = ["lactose", "fructose", "histamine", "fodmap"];
const CONDITION_IDS = ["celiac", "diabetes", "hypertension", "kidney_disease", "gout", "favism"];
const DIET_IDS = ["vegetarian", "vegan", "pescatarian", "halal", "kosher"];
const SITUATION_IDS = ["pregnant", "breastfeeding"];

const CATEGORY_ICONS = [
  "beer", "dinner", "fried-rice", "lasagna", "lunch-bag", "nachos",
  "pancake", "pasta", "pastry", "pizza-slice", "ramen", "restaurant",
  "rice", "salad", "sausage", "shrimp", "taco",
];

function buildSystemPrompt(userLanguage) {
  const allIDs = [...ALLERGEN_IDS, ...INTOLERANCE_IDS, ...CONDITION_IDS, ...DIET_IDS, ...SITUATION_IDS].join(", ");
  const icons = CATEGORY_ICONS.join(", ");

  return `You are a menu analysis assistant. Analyze the restaurant menu image(s) and return ONLY valid JSON with this exact structure:
{
  "restaurant": "Name of the restaurant if visible, otherwise 'Unknown'",
  "categoryIcon": "best matching icon for this restaurant type",
  "menuLanguage": "detected language of the menu",
  "dishes": [
    {
      "name": "Dish name translated to ${userLanguage}",
      "description": "Original dish name as written on the menu",
      "price": "Price if visible",
      "category": "Menu section translated to ${userLanguage} with original in parentheses",
      "ingredients": ["ingredient1", "ingredient2"],
      "allergenIds": ["id1", "id2"]
    }
  ]
}

Rules:
- LANGUAGE: All dish names, categories, and ingredients MUST be translated to ${userLanguage}. Keep the original name in the description field.
- For ingredients: list the most likely ingredients even if not explicitly stated on the menu. Use your culinary knowledge. Translate them to ${userLanguage}.
- For allergenIds: tag each dish with ALL applicable IDs from this list: ${allIDs}
  These cover allergens (gluten, dairy, eggs…), intolerances (lactose, fructose, histamine, fodmap), medical conditions the dish is problematic for (celiac, diabetes=high sugar, hypertension=high sodium, kidney_disease=high potassium/phosphorus, gout=high purines, favism=fava beans), diets the dish violates (vegetarian=contains meat/fish, vegan=contains any animal product, pescatarian=contains meat but not fish, halal=contains pork/alcohol, kosher=not kosher), and situations where the dish should be avoided (pregnant=raw fish/unpasteurized/high mercury, breastfeeding=alcohol/high caffeine).
- For categoryIcon: pick the SINGLE best matching icon from this list based on the restaurant's cuisine type: ${icons}. If none fits well, use "restaurant".
- For menuLanguage: detect the original language of the menu text and return its name in English (e.g. "Italian", "Japanese", "Spanish").
- For category: translate the menu section heading to ${userLanguage} and include the original in parentheses (e.g. "Land Appetizers (Antipasti di Terra)").
- For description: always put the original dish name as written on the menu (in its original language).
- Include ALL dishes visible in the menu image(s).
- Return ONLY the JSON, no markdown formatting, no code fences, no extra text.`;
}

exports.analyzeMenu = onCall(
  {
    secrets: [openaiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
    maxInstances: 10,
  },
  async (request) => {
    const { base64Images, userLanguage } = request.data;

    if (!base64Images?.length || !userLanguage) {
      throw new HttpsError("invalid-argument", "Missing base64Images or userLanguage");
    }

    const systemPrompt = buildSystemPrompt(userLanguage);

    const imageContents = base64Images.map((b64) => ({
      type: "image_url",
      image_url: { url: `data:image/jpeg;base64,${b64}`, detail: "high" },
    }));

    const body = {
      model: MODEL,
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [
            { type: "text", text: "Analyze this restaurant menu and return the structured JSON." },
            ...imageContents,
          ],
        },
      ],
      max_tokens: 4096,
      temperature: 0.1,
    };

    const response = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new HttpsError("internal", `OpenAI error (${response.status}): ${errText}`);
    }

    const data = await response.json();

    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      throw new HttpsError("internal", "No content in OpenAI response");
    }

    const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

    try {
      return JSON.parse(cleaned);
    } catch {
      throw new HttpsError("internal", "Failed to parse OpenAI JSON response");
    }
  }
);

exports.retranslateMenu = onCall(
  {
    secrets: [openaiKey],
    timeoutSeconds: 60,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    const { dishesJSON, targetLanguage } = request.data;

    if (!dishesJSON || !targetLanguage) {
      throw new HttpsError("invalid-argument", "Missing dishesJSON or targetLanguage");
    }

    const systemPrompt = `You are a translation assistant. Translate menu dishes to ${targetLanguage}.
For each dish:
- "name": translate the dish name to ${targetLanguage}
- "description": keep EXACTLY as is (original name from menu)
- "price": keep EXACTLY as is
- "category": translate to ${targetLanguage} with original in parentheses
- "ingredients": translate all to ${targetLanguage}
- "allergenIds": keep EXACTLY as is
Return ONLY a valid JSON array. No markdown, no code fences, no extra text.`;

    const body = {
      model: MODEL,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: dishesJSON },
      ],
      max_tokens: 4096,
      temperature: 0.1,
    };

    const response = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new HttpsError("internal", `OpenAI error (${response.status}): ${errText}`);
    }

    const data = await response.json();

    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      throw new HttpsError("internal", "No content in OpenAI response");
    }

    const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();

    try {
      return JSON.parse(cleaned);
    } catch {
      throw new HttpsError("internal", "Failed to parse OpenAI JSON response");
    }
  }
);
