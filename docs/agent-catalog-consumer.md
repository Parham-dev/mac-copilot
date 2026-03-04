# CopilotForge Agent Catalog — General / Consumer

Date: 2026-03-04

Agents for everyone — writers, creators, founders, freelancers, students, marketers. Not dev-focused. These are the agents that make people say "I need this app."

---

## Capabilities We're Using

| Power | How agents use it |
|-------|-------------------|
| **Web search + fetch** | Research anything — companies, topics, trends, people, products |
| **Shell** | Run `ffmpeg` (audio/video), `curl` (APIs), `python` (data), `pandoc` (format conversion) |
| **File I/O** | Read/write documents, save generated images, export reports |
| **Replicate API** (via shell + API key) | Generate images (Flux, SDXL), video (Stable Video), audio, upscale |
| **GitHub MCP** | Already authed — useful for open-source project context |
| **MCP infra** | Add any service integration |

---

## Agent Catalog

### 1. social-media-creator

**UX Mode:** Setup-First → Run

**What:** Give it a topic or brief, get a complete social media content package — platform-optimised copy, generated images, hashtags, posting schedule. One brief → content for Twitter/X, LinkedIn, Instagram, Threads.

**Required connections:** `replicate-api-key` (for image generation)

**Inputs:**
- `brief` (text) — what you want to post about
- `platform` (select) — Twitter/X, LinkedIn, Instagram, Threads, all
- `contentType` (select) — text post, image post, carousel, thread, story
- `tone` (select) — professional, casual, provocative, educational, storytelling, humorous
- `referenceURL` (url) — optional link for context/research

**What the agent does:**
1. Researches topic via `web_search` + `web_fetch`
2. Drafts platform-optimised copy (char limits, formatting, hooks per platform)
3. Generates image prompts based on content
4. Calls Replicate API via `shell` to generate images (Flux/SDXL)
5. Downloads images to agent sandbox
6. Outputs: copy per platform + images + hashtags + posting times

**Output:** Post copy (per platform), generated images, hashtag sets, A/B variants, optimal posting times.

---

### 2. blog-writer

**UX Mode:** Run

**What:** Research a topic and write a full blog post — with outline, SEO keywords, internal/external links, and a meta description. Not a ChatGPT dump — it actually researches first, then writes.

**Inputs:**
- `topic` (text) — what the article is about
- `targetKeyword` (text) — primary SEO keyword (optional)
- `audience` (select) — general, technical, business, beginner, expert
- `length` (select) — short (800w), medium (1500w), long (2500w+), pillar (4000w+)
- `tone` (select) — informative, conversational, authoritative, storytelling, listicle
- `competitorURLs` (text) — URLs of competing articles to outrank (optional)
- `existingDraft` (text) — paste a rough draft to improve (optional)

**What the agent does:**
1. `web_search` for top-ranking articles on the topic
2. `web_fetch` competitor articles for angle analysis
3. Extracts common subtopics, gaps, unique angles
4. Generates outline with H2/H3 structure
5. Writes the full article with SEO best practices
6. Generates meta title, meta description, slug
7. Suggests internal link opportunities

**Output:** Full article (markdown), outline, meta title/description, keyword density report, suggested images/alt-text, related topic ideas for content clusters.

**Tools:** `web_search`, `web_fetch`

---

### 3. thumbnail-generator

**UX Mode:** Setup-First → Run

**What:** Generate YouTube/blog thumbnails, social media graphics, and cover images from a text description. Uses Replicate models optimised for different styles.

**Required connections:** `replicate-api-key`

**Inputs:**
- `concept` (text) — describe the image you want
- `style` (select) — photorealistic, illustration, 3D render, flat design, neon, minimalist, collage
- `dimensions` (select) — YouTube thumbnail (1280x720), Instagram square (1080x1080), LinkedIn banner (1584x396), Twitter header (1500x500), custom
- `textOverlay` (text) — text to include on the image (optional)
- `colorPalette` (text) — brand colors or mood (optional)
- `variations` (select) — 1, 3, 5

**What the agent does:**
1. Crafts optimised prompts for the selected style
2. Calls Replicate (Flux Pro / SDXL) via `shell`
3. Generates multiple variations
4. Downloads all to agent sandbox
5. If text overlay requested, uses `ffmpeg` or ImageMagick via `shell` to composite text

**Output:** Generated images (downloadable), prompt used, style notes.

**Tools:** `shell` (curl Replicate + ffmpeg/imagemagick)

---

### 4. newsletter-writer

**UX Mode:** Run

**What:** Curate + write a newsletter issue. Feed it your topic/niche, it searches for the latest news and trends, then writes an engaging newsletter with sections, links, and a personal take.

**Inputs:**
- `niche` (text) — your newsletter's topic area (AI, indie hacking, design, etc.)
- `edition` (text) — issue name/number (optional)
- `sections` (select) — top stories + analysis, quick links roundup, tool spotlight, opinion piece, all
- `tone` (select) — curator, analyst, friend, pundit
- `audienceSize` (select) — small/personal, growing, professional, enterprise
- `recentURLs` (text) — links you want to include (optional)

**What the agent does:**
1. `web_search` for latest news, launches, trends in the niche (last 7 days)
2. `web_fetch` top results for deeper context
3. Curates the most interesting/relevant items
4. Writes each section with summaries, opinions, and source links
5. Adds intro hook and closing CTA
6. Formats for email (clean markdown → ready to paste into Substack/Beehiiv/Mailchimp)

**Output:** Full newsletter issue (markdown), subject line options, preview text, source links.

**Tools:** `web_search`, `web_fetch`

---

### 5. resume-tailor

**UX Mode:** Run

**What:** Paste your resume + a job posting, get a tailored version that matches the role's keywords, requirements, and tone — without lying.

**Inputs:**
- `resume` (text) — paste your current resume
- `jobPosting` (text) — paste the job description
- `style` (select) — traditional, modern, technical, creative, executive
- `focus` (select) — match keywords, highlight achievements, rewrite summary, reorder sections, full rewrite
- `additionalContext` (text) — things not on your resume but relevant (optional)

**What the agent does:**
1. Parses job posting for required skills, keywords, and culture signals
2. Maps your experience to job requirements
3. Rewrites bullet points to mirror job language
4. Adds missing keywords where you have genuine experience
5. Rewrites summary/objective for the specific role
6. Optionally researches the company via `web_search` for culture fit angles

**Output:** Tailored resume (markdown), keyword match score, cover letter draft, things to emphasise in interview, gaps to address.

**Tools:** `web_search` (for company research, optional)

---

### 6. product-launch-kit

**UX Mode:** Run

**What:** You're launching a product. This agent generates your entire launch package — landing page copy, Product Hunt description, Twitter/X launch thread, email announcement, press release, and social media assets.

**Required connections:** `replicate-api-key` (optional, for OG image generation)

**Inputs:**
- `productName` (text) — what it's called
- `productURL` (url) — landing page or docs
- `oneLiner` (text) — one-sentence description
- `targetAudience` (text) — who it's for
- `launchPlatform` (select) — Product Hunt, Hacker News, Twitter/X, all
- `tone` (select) — excited, professional, indie hacker, enterprise

**What the agent does:**
1. `web_fetch` the product URL for context
2. Researches competitors/alternatives via `web_search`
3. Generates launch copy for each platform
4. Writes Product Hunt description (tagline, description, first comment)
5. Writes Twitter/X launch thread (hook → features → CTA)
6. Writes email announcement for existing users
7. Writes press release template
8. Generates OG image via Replicate if API key available

**Output:** Product Hunt listing (tagline + description + first comment + maker comment), Twitter launch thread, email announcement, HN Show post, press release, OG image.

---

### 7. video-script-writer

**UX Mode:** Run

**What:** Write a complete video script — YouTube, TikTok, course, presentation. Includes hook, structure, visual cues, and CTA. Researches the topic first.

**Inputs:**
- `topic` (text) — what the video is about
- `platform` (select) — YouTube (long), YouTube Shorts, TikTok, course module, presentation
- `duration` (select) — 30s, 60s, 3-5min, 10-15min, 20min+
- `style` (select) — educational, entertaining, storytelling, tutorial, review, commentary
- `audience` (text) — who's watching
- `referenceVideos` (text) — URLs of videos with the style you want (optional)

**What the agent does:**
1. Researches topic via `web_search`
2. If reference URLs provided, `web_fetch` for structure analysis
3. Writes script with: hook (first 5 seconds), structure, visual/B-roll cues, transitions, CTA
4. Adds timestamps, scene descriptions, and on-screen text suggestions
5. Calculates approximate word count for target duration

**Output:** Full script with timestamps, visual cues per section, hook options (3 variations), thumbnail concepts, title + description for SEO, tags.

**Tools:** `web_search`, `web_fetch`

---

### 8. pitch-deck-writer

**UX Mode:** Run

**What:** Write the content for a pitch deck — investor, client, partnership, internal. Gives you slide-by-slide copy with speaker notes.

**Inputs:**
- `company` (text) — company/product name
- `companyURL` (url) — website (optional, for research)
- `deckType` (select) — investor seed, investor series A, client proposal, partnership, internal strategy
- `keyMetrics` (text) — revenue, users, growth rate, etc.
- `problem` (text) — the problem you solve
- `askAmount` (text) — funding ask or deal size (optional)

**What the agent does:**
1. `web_fetch` company URL for context
2. `web_search` for market size, competitors, trends
3. Generates slide-by-slide content following proven frameworks (problem → solution → traction → team → ask)
4. Writes speaker notes per slide
5. Suggests data visualisations for metrics

**Output:** Slide-by-slide copy (10-15 slides), speaker notes, data viz suggestions, appendix slides, common investor questions + preparation notes.

**Tools:** `web_search`, `web_fetch`

---

### 9. weekly-digest

**UX Mode:** Run

**What:** Stay on top of any industry or topic. Give it your interests, get a curated weekly briefing with the most important developments, takes, and links.

**Inputs:**
- `topics` (text) — comma-separated topics/industries to track
- `depth` (select) — headlines only, summaries, deep analysis
- `sources` (text) — preferred sources/publications (optional)
- `antiTopics` (text) — things to exclude (optional)
- `format` (select) — executive brief, newsletter style, bullet points, narrative

**What the agent does:**
1. `web_search` each topic (filtered to last 7 days)
2. `web_fetch` top results for richer context
3. Cross-references for most-discussed developments
4. Ranks by relevance and impact
5. Writes summaries with source links
6. Identifies emerging trends across topics

**Output:** Curated digest with ranked stories, trend analysis, key quotes, source links, "what to watch next week."

**Tools:** `web_search`, `web_fetch`

---

### 10. contract-reviewer

**UX Mode:** Run

**What:** Paste a contract or legal document, get a plain-English summary of what it says, what's risky, what's missing, and what to negotiate.

**Inputs:**
- `document` (text) — paste the contract text
- `role` (select) — I'm the freelancer, I'm the client, I'm the employee, I'm the vendor, I'm the founder
- `focusAreas` (select) — payment terms, liability, IP ownership, termination, non-compete, data privacy, all
- `jurisdiction` (text) — country/state (optional, for context)

**Output:** Plain-English summary, clause-by-clause breakdown, risk flags (red/yellow/green), missing protections, negotiation suggestions, comparison to standard terms.

**Tools:** none (pure text analysis). Disclaimer: not legal advice.

---

### 11. brand-voice-builder

**UX Mode:** Run

**What:** Analyse your existing content (website, social posts, emails) and generate a comprehensive brand voice guide — tone, vocabulary, do's and don'ts, example rewrites.

**Inputs:**
- `contentURLs` (text) — URLs of your existing content (website, blog, social profiles)
- `additionalContent` (text) — paste any existing copy (emails, posts, etc.)
- `industry` (select) — tech, finance, health, education, creative, retail, SaaS
- `aspirationalBrands` (text) — brands whose voice you admire (optional)

**What the agent does:**
1. `web_fetch` all provided URLs
2. Analyses tone, vocabulary, sentence structure, formality level
3. Identifies patterns and inconsistencies
4. If aspirational brands provided, `web_fetch` their content for comparison
5. Generates comprehensive voice guide

**Output:** Voice profile (adjectives, tone spectrum, reading level), vocabulary list (words to use / words to avoid), example rewrites of your content, templates for different content types (email, social, landing page), before/after comparisons.

**Tools:** `web_fetch`, `web_search`

---

### 12. lead-researcher

**UX Mode:** Run

**What:** Research a person, company, or topic deeply. Compiles everything publicly available into a structured brief. Perfect for sales prep, due diligence, or journalism.

**Inputs:**
- `subject` (text) — person name, company name, or topic
- `subjectURLs` (text) — known URLs (LinkedIn, website, Crunchbase, etc.)
- `purpose` (select) — sales call prep, investment due diligence, partnership evaluation, journalism, competitive analysis, hiring
- `depth` (select) — quick overview (2 min), standard brief, deep dive

**What the agent does:**
1. `web_search` subject name + variations
2. `web_fetch` all discoverable pages (website, LinkedIn, Crunchbase, press)
3. Cross-references information
4. Structures findings by category (background, recent activity, financials if available, red flags, connections)
5. Identifies talking points or angles based on purpose

**Output:** Structured research brief, source links, key facts, recent activity timeline, potential talking points, unanswered questions.

**Tools:** `web_search`, `web_fetch`

---

### 13. course-outline-builder

**UX Mode:** Run

**What:** Design a complete online course or workshop structure. Researches existing courses on the topic, identifies gaps, and generates module-by-module outline with lesson plans.

**Inputs:**
- `topic` (text) — what the course teaches
- `format` (select) — self-paced video, live cohort, workshop, mini-course, bootcamp
- `duration` (select) — 1 hour, half day, multi-day, 4-week, 8-week
- `audience` (select) — beginner, intermediate, advanced, mixed
- `competitorCourses` (text) — URLs of existing courses to differentiate from (optional)

**What the agent does:**
1. `web_search` for existing courses on the topic
2. `web_fetch` competitor course pages for curriculum analysis
3. Identifies common topics and gaps
4. Designs module structure with learning objectives
5. Generates lesson plans per module
6. Suggests exercises, projects, and assessment ideas

**Output:** Course outline (modules → lessons → learning objectives), suggested exercises per module, recommended resources, pricing analysis of competitors, differentiation strategy, launch plan.

**Tools:** `web_search`, `web_fetch`

---

### 14. ad-copy-generator

**UX Mode:** Run

**What:** Generate ad copy for any platform — Google Ads, Facebook/Meta, LinkedIn Ads, Twitter/X Ads. Multiple variations optimised for each platform's constraints.

**Inputs:**
- `productURL` (url) — landing page
- `targetAudience` (text) — who you're targeting
- `platform` (select) — Google Search, Google Display, Facebook/Meta, Instagram, LinkedIn, Twitter/X, all
- `objective` (select) — awareness, traffic, conversions, leads, app installs
- `budget` (select) — bootstrapped, moderate, growth, enterprise
- `competitorURLs` (text) — competitor landing pages (optional)

**What the agent does:**
1. `web_fetch` product landing page for messaging and value props
2. If competitors provided, `web_fetch` their pages for differentiation
3. `web_search` for industry benchmark CTRs and best practices
4. Generates ad copy per platform (respecting char limits, headline/description structure)
5. Creates multiple variations per ad group
6. Suggests audience targeting parameters

**Output:** Ad copy per platform (5+ variations each), headline/description pairs, display URL suggestions, audience targeting recommendations, A/B testing plan, negative keyword suggestions (Google).

**Tools:** `web_fetch`, `web_search`

---

### 15. meal-planner

**UX Mode:** Run

**What:** Generate a personalised weekly meal plan with recipes, grocery list, and nutritional estimates. Accounts for dietary restrictions, budget, and cooking skill.

**Inputs:**
- `dietaryNeeds` (text) — allergies, restrictions, preferences (vegan, keto, halal, etc.)
- `mealsPerDay` (select) — 2, 3, 3 + snacks
- `cookingSkill` (select) — beginner, intermediate, advanced
- `timePerMeal` (select) — 15 min, 30 min, 1 hour, no limit
- `budget` (select) — tight, moderate, no limit
- `servings` (select) — 1, 2, family (4+)
- `cuisine` (text) — preferred cuisines (optional)

**What the agent does:**
1. Generates balanced meal plan for 7 days
2. Each meal: recipe name, ingredients, steps, prep/cook time, macros estimate
3. Consolidates into a single grocery list (sorted by store section)
4. Calculates rough cost estimate
5. Suggests batch-cooking strategy to save time

**Output:** 7-day meal plan with recipes, consolidated grocery list, estimated macros per day, batch-cooking tips, substitution suggestions.

**Tools:** `web_search` (for recipe inspiration), none required

---

## Priority Order

| # | Agent | Setup needed | Why it's compelling |
|---|-------|-------------|---------------------|
| 1 | **blog-writer** | None | Zero friction. Everyone needs content. Researches first = actually useful. |
| 2 | **social-media-creator** | Replicate API key | Visual output = wow factor. Multi-platform = saves hours. |
| 3 | **newsletter-writer** | None | Growing market. Research + curation is the hard part. |
| 4 | **resume-tailor** | None | Universal need. Emotional urgency (job hunting). Viral potential. |
| 5 | **thumbnail-generator** | Replicate API key | Visual. Fast. Every YouTuber/blogger needs this. |
| 6 | **video-script-writer** | None | Creator economy is massive. Research-backed scripts stand out. |
| 7 | **product-launch-kit** | None (Replicate optional) | Founders launch constantly. All-in-one = massive time save. |
| 8 | **lead-researcher** | None | Sales + biz dev use daily. Deep web research = real value. |
| 9 | **pitch-deck-writer** | None | Every startup pitches. Market-research-backed = credible. |
| 10 | **ad-copy-generator** | None | Anyone running ads. Platform-specific formatting = tedious manual work. |
| 11 | **brand-voice-builder** | None | Unique — most AI tools can't do this. Analyses your actual content. |
| 12 | **weekly-digest** | None | Personal curation. Stays relevant weekly. |
| 13 | **contract-reviewer** | None | Freelancers, founders, employees. High emotional value. |
| 14 | **course-outline-builder** | None | Creator economy + edtech intersection. |
| 15 | **meal-planner** | None | Just fun and useful. Broadens audience beyond knowledge workers. |

---

## Key Insight

12 of 15 agents need **zero** setup — no API keys, no connections, no accounts. They use `web_search` + `web_fetch` which are already working. The only agents needing a connection are the image-generating ones (`replicate-api-key`).

This means we can ship 12 agents on day one of the consumer launch with zero additional infrastructure beyond the existing Run agent UX.
