import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient } from "../_shared/supabase-client.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createUserClient(req);

    // Verify the user is authenticated
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          detail: authError?.message ?? "No user found",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const body = await req.json();
    const { username, first_name, middle_name, last_name, dupr_id, dupr_rating, latitude, longitude } = body;

    // --- Detect DUPR user via user_metadata ---
    const meta = user.user_metadata ?? {};
    const isDuprUser = !!meta.dupr_id;

    // --- Validate required fields ---

    if (!username || typeof username !== "string" || username.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "username is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (username.trim().length < 3 || username.trim().length > 30) {
      return new Response(
        JSON.stringify({ error: "username must be between 3 and 30 characters" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // --- Resolve name and rating based on auth method ---

    let resolvedFirstName: string;
    let resolvedLastName: string;
    let resolvedMiddleName: string | undefined;
    let resolvedDuprRating: number;
    let resolvedDuprId: string | undefined;
    let resolvedDuprVerified: boolean;
    let resolvedDuprSinglesRating: number | null = null;
    let resolvedDoublesRating: number | null = null;
    let resolvedEntitlements: string[] | undefined;

    if (isDuprUser) {
      // DUPR user: pull name/rating from user_metadata, body fields are optional overrides
      resolvedFirstName = (first_name?.trim() || meta.first_name || "").trim();
      resolvedLastName = (last_name?.trim() || meta.last_name || "").trim();
      resolvedDuprRating = meta.dupr_rating ?? 2.0;
      resolvedDuprId = meta.dupr_id;
      resolvedDuprVerified = true;
      resolvedDuprSinglesRating = meta.dupr_singles_rating ?? null;
      resolvedDoublesRating = meta.dupr_doubles_rating ?? null;
      resolvedEntitlements = meta.dupr_entitlements;
    } else {
      // Non-DUPR user (magic link): require name fields, assign beginner rating
      if (!first_name || typeof first_name !== "string" || first_name.trim().length === 0) {
        return new Response(
          JSON.stringify({ error: "first_name is required" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      if (first_name.trim().length > 50) {
        return new Response(
          JSON.stringify({ error: "first_name must be 50 characters or fewer" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      if (!last_name || typeof last_name !== "string" || last_name.trim().length === 0) {
        return new Response(
          JSON.stringify({ error: "last_name is required" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      if (last_name.trim().length > 50) {
        return new Response(
          JSON.stringify({ error: "last_name must be 50 characters or fewer" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      resolvedFirstName = first_name.trim();
      resolvedLastName = last_name.trim();
      resolvedDuprRating = dupr_rating ?? 2.0;
      resolvedDuprId = dupr_id;
      resolvedDuprVerified = false;
    }

    // Validate middle_name if provided (both flows)
    if (middle_name != null && typeof middle_name === "string" && middle_name.trim().length > 50) {
      return new Response(
        JSON.stringify({ error: "middle_name must be 50 characters or fewer" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    resolvedMiddleName =
      middle_name != null && typeof middle_name === "string" && middle_name.trim().length > 0
        ? middle_name.trim()
        : undefined;

    // Validate rating range
    if (resolvedDuprRating < 1.0 || resolvedDuprRating > 8.0) {
      return new Response(
        JSON.stringify({ error: "dupr_rating must be between 1.0 and 8.0" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // --- Check if profile already exists ---

    const { data: existing } = await supabase
      .from("users")
      .select("id")
      .eq("id", user.id)
      .maybeSingle();

    if (existing) {
      return new Response(
        JSON.stringify({ error: "Profile already exists. Use update-profile instead." }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // --- Build the insert row ---

    const row: Record<string, unknown> = {
      id: user.id,
      username: username.trim(),
      first_name: resolvedFirstName,
      last_name: resolvedLastName,
      dupr_rating: resolvedDuprRating,
      dupr_verified: resolvedDuprVerified,
    };

    if (resolvedMiddleName) row.middle_name = resolvedMiddleName;
    if (resolvedDuprId) row.dupr_id = resolvedDuprId;
    if (resolvedDuprSinglesRating != null) row.dupr_singles_rating = resolvedDuprSinglesRating;
    if (resolvedDoublesRating != null) row.dupr_doubles_rating = resolvedDoublesRating;
    if (resolvedEntitlements) {
      row.dupr_entitlements = resolvedEntitlements;
      row.dupr_entitlements_cached_at = new Date().toISOString();
    }

    if (latitude != null && longitude != null) {
      row.location = `SRID=4326;POINT(${longitude} ${latitude})`;
    }

    // --- Insert profile ---

    const { data: profile, error: insertError } = await supabase
      .from("users")
      .insert(row)
      .select()
      .single();

    if (insertError) {
      // Handle unique constraint on username
      if (insertError.code === "23505" && insertError.message.includes("username")) {
        return new Response(
          JSON.stringify({ error: "Username is already taken" }),
          {
            status: 409,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      throw insertError;
    }

    return new Response(
      JSON.stringify({ success: true, profile }),
      {
        status: 201,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
