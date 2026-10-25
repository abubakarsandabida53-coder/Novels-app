# NovelVerse setup
1. Supabase: create project > SQL Editor > run `supabase/schema.sql`.
2. Auth > URL Configuration: set Site URL to your Netlify URL (and http://localhost:8888 for tests).
3. Put your Project URL + anon key in `config.js` (never the service-role key).
4. Sign up in the app, then run the commented "FIRST ADMIN" SQL at the bottom of schema.sql with your email. Reload: Profile > Admin dashboard.
5. Deploy: drag this folder into Netlify (no build step).
6. Test PWA on Android: open the Netlify URL in Chrome > menu > Install app. Later: wrap with Bubblewrap/PWABuilder for Play Store (add 192/512 PNG icons first).
Not yet built: payments (Paystack webhook Edge Function), AI narration, notifications, ads, author accounts, account-delete function, offline downloads.

## Phase 2 (payments, AI narration, alerts, ads, offline audio, legal, moderation)
1. SQL Editor: run `supabase/migration_002.sql`. Prices are placeholders; edit in Admin: more.
2. Install Supabase CLI, then:
   `supabase secrets set PAYSTACK_SECRET_KEY=sk_test_... SITE_URL=https://your-site.netlify.app OPENAI_API_KEY=sk-...` (OPENAI_API_KEY optional; AI narration stays off without it)
   `supabase functions deploy paystack-init tts-generate delete-account`
   `supabase functions deploy paystack-webhook --no-verify-jwt`
3. Paystack dashboard > Settings > API: set webhook URL to `https://YOUR-PROJECT.supabase.co/functions/v1/paystack-webhook`. Test with sk_test keys first.
4. Long chapters can hit the Edge Function time limit on AI narration; generate those in smaller chapters.
Still not built: author accounts, push notifications, offline text reading, Flutterwave/Stripe, promo codes.
