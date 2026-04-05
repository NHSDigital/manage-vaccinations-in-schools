def confirm_production(env):
    """Prompt for confirmation before operating on production."""
    if env != "production":
        return
    print("Warning: You are about to operate on PRODUCTION (not data-replication).")
    answer = input("Type 'production' to continue: ").strip()
    if answer != "production":
        raise RuntimeError("Production confirmation failed")
