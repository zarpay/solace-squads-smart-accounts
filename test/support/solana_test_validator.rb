# frozen_string_string: true

module Solace
  module SquadsSmartAccounts
    module Test
      class SolanaTestValidator
        def before_all
          super
          @validator_pid = spawn('solana-test-validator', out: File.join(__dir__, '../../logs/validator.log'), err: File::APPEND)

          # Wait for validator to be ready
          timeout = 30
          start_time = Time.now
          until system('solana cluster-info', out: File::NULL)
            sleep 1
            raise "Validator failed to start within #{timeout}s" if Time.now - start_time > timeout
          end

          puts "\n[Solace-Squads] Solana test validator started."
        end

        def after_all
          super

          begin
            Process.kill('TERM', @validator_pid)
            Process.wait(@validator_pid)
          rescue StandardError
            nil
          end

          puts '[Solace-Squads] Solana test validator stopped.'
        end
      end
    end
  end
end
