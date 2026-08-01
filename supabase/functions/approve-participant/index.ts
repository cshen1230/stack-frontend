import { corsHeaders } from "../_shared/cors.ts";
import {
  createUserClient,
  createAdminClient,
} from "../_shared/supabase-client.ts";

/**
 * Approve — or decline — a pending add to a session.
 *
 * Who may approve is decided entirely by can_approve_participant() in the database, not here.
 * The rule it encodes (the host far out; anyone already playing within 3h of start; never the
 * person who proposed the add) is the same rule SessionApproval enforces in the client, and
 * keeping it in one place is the point: the client copy is there to grey out a button, and this
 * one is there to actually stop anybody.
 *
 * A pending row holds no seat. That's why the increment happens here rather than at invite
 * time — the seat is taken at the moment two people agree, so a request that sits unanswered
 * never starves a session that needed the spot.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status: number) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const supabase = createUserClient(req);

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const { participant_id, decision } = await req.json();
    if (!participant_id) {
      return json({ error: "participant_id is required" }, 400);
    }

    const action = decision ?? "approve";
    if (action !== "approve" && action !== "decline") {
      return json({ error: "decision must be 'approve' or 'decline'" }, 400);
    }

    const admin = createAdminClient();

    // The authority for both paths. Declining is a decision about someone else's request too,
    // so it takes the same standing approving does — otherwise anyone could quietly bin an add
    // they had no say over.
    //
    // Asked through the admin client so the answer is the rule and nothing else: run as the
    // caller, RLS could hide a roster row and turn a legitimate approver into a 403. The id
    // being asked about is passed explicitly and comes from the verified token, so this grants
    // nothing the caller didn't already have.
    const { data: canApprove, error: guardError } = await admin.rpc(
      "can_approve_participant",
      { p_approver: user.id, p_participant_id: participant_id },
    );
    if (guardError) throw guardError;

    if (!canApprove) {
      return json(
        {
          error:
            "You can't approve this one — it needs the host, or someone else already handled it.",
        },
        403,
      );
    }

    if (action === "decline") {
      const { error: declineError } = await admin
        .from("game_participants")
        .update({ rsvp_status: "cancelled", approved_by: user.id })
        .eq("id", participant_id)
        .eq("rsvp_status", "pending_approval");
      if (declineError) throw declineError;

      return json({ success: true, approved: false, message: "Declined" }, 200);
    }

    // Claim the row first, and only if it is still pending. Two approvers racing means the
    // second one updates nothing, so only one of them goes on to take a seat.
    const { data: claimed, error: claimError } = await admin
      .from("game_participants")
      .update({ rsvp_status: "confirmed", approved_by: user.id })
      .eq("id", participant_id)
      .eq("rsvp_status", "pending_approval")
      .select("id, game_id")
      .maybeSingle();
    if (claimError) throw claimError;

    if (!claimed) {
      return json({ error: "That request was already handled" }, 409);
    }

    // Same atomic increment every other join path uses; it refuses once the game is full.
    const { error: rpcError } = await admin.rpc("increment_spots_filled", {
      p_game_id: claimed.game_id,
    });

    if (rpcError) {
      // The seat went while we were approving. Put the row back rather than leaving someone
      // confirmed into a session with no room for them.
      await admin
        .from("game_participants")
        .update({ rsvp_status: "pending_approval", approved_by: null })
        .eq("id", participant_id);

      return json(
        { error: "The session filled up before this was approved" },
        409,
      );
    }

    return json(
      { success: true, approved: true, message: "Added to the session" },
      200,
    );
  } catch (err) {
    return json({ error: err.message }, 500);
  }
});
