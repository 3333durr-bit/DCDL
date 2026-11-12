import { supabase } from './supabase';

function requireSupabase() {
  if (!supabase) {
    throw new Error('Supabase is not configured. Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to .env.local.');
  }
  return supabase;
}

export async function registerWithEmail(input: {
  email: string;
  password: string;
  gdUsername: string;
  country: string;
}) {
  const client = requireSupabase();
  const { data, error } = await client.auth.signUp({
    email: input.email,
    password: input.password,
    options: {
      data: {
        gd_username: input.gdUsername.trim(),
        country: input.country.trim(),
      },
    },
  });
  if (error) throw error;
  return data;
}

export async function signInWithEmail(email: string, password: string) {
  const { data, error } = await requireSupabase().auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function signOut() {
  const { error } = await requireSupabase().auth.signOut();
  if (error) throw error;
}
