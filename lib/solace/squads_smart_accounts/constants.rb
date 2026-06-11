# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Canonical on-chain program ID for the Squads Smart Account program.
    PROGRAM_ID = 'SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG'

    # Cluster-scoped aliases — provided for consistency; both resolve to the
    # same program ID since Squads deploys identically across clusters.
    MAINNET_PROGRAM_ID = PROGRAM_ID
    DEVNET_PROGRAM_ID  = PROGRAM_ID
  end
end
