# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Canonical on-chain program ID for the Squads Smart Account program.
    PROGRAM_ID = 'SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG'

    # Cluster-scoped aliases — provided for consistency; both resolve to the
    # same program ID since Squads deploys identically across clusters.
    MAINNET_PROGRAM_ID = PROGRAM_ID
    DEVNET_PROGRAM_ID  = PROGRAM_ID

    # PDA for the global program config account, derived from seeds ["smart_account", "program_config"].
    # Holds the treasury address and smart account creation fee.
    PROGRAM_CONFIG_ADDRESS = 'GmY9kVi3FhrCUn2MJkzzpE6C5618YoHuGsgqHU78cKus'

    # Base58 of Pubkey::default() (32 zero bytes). The program stores this as
    # the settings_authority of autonomous smart accounts; handing the authority
    # to this key permanently renounces control (nobody can sign as it).
    DEFAULT_PUBKEY = '11111111111111111111111111111111'
  end
end
