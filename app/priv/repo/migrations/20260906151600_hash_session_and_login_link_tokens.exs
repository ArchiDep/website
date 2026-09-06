defmodule ArchiDep.Repo.Migrations.HashSessionAndLoginLinkTokens do
  use Ecto.Migration

  # Session and login-link tokens are bearer credentials: whoever holds one is
  # the user until it expires. Stored as they are handed out, anyone who can
  # read these two tables — a replica, a dump, an injection elsewhere — can
  # replay every one of them. Storing the SHA-256 of a token instead keeps the
  # lookup working (the same hash is computed from what the caller presents)
  # while leaving nothing replayable in the row.
  #
  # The existing rows are hashed in place rather than deleted, so the sessions
  # and links already handed out go on working: the column holds the very tokens
  # whose hashes it needs, which is the whole reason this migration is possible
  # without logging everyone out. It is also the last moment it is possible —
  # after this the raw tokens are gone, which is the point.
  def up do
    rename table(:user_sessions), :token, to: :token_hash
    rename table(:login_links), :token, to: :token_hash

    execute("UPDATE user_sessions SET token_hash = sha256(token_hash)")
    execute("UPDATE login_links SET token_hash = sha256(token_hash)")
  end

  # A hash cannot be turned back into the token it was made from, so there is no
  # rolling this back with the sessions and links intact: rows whose column held
  # a hash would authenticate nobody, the tokens their holders present hashing
  # to something else again. They are dropped instead, which logs everyone out
  # and voids the outstanding links — the honest outcome of undoing this.
  def down do
    execute("DELETE FROM user_sessions")
    execute("DELETE FROM login_links")

    rename table(:user_sessions), :token_hash, to: :token
    rename table(:login_links), :token_hash, to: :token
  end
end
