class Registration
    include Mongoid::Document
    field :paid, type: Boolean
    field :status
    field :player_strength
    field :signup_timestamp, type: DateTime
    field :payment_timestamps, type: Hash, default: {}
    field :pair, type: Hash
    field :gender
    field :availability, type: Hash
    field :team_style_pref, type: Hash
    field :secondary_rank_data, type: Hash
    field :waiver_acceptance_date, type: DateTime
    field :user_data, type: Hash
    field :notes

    field :paypal_responses, type: Array, default: []
    field :payment_id

    belongs_to :user
    belongs_to :league

    def self_rank
        if secondary_rank_data.nil?
            nil
        else
            secondary_rank_data['self_rank']
        end
    end

    def waiver_accepted
        !waiver_acceptance_date.nil?
    end

    def capture_payment
        raise PaymentNotAuthorized if status != 'authorized'
        raise PaymentInfoMissing unless payment_id

        payment = PayPal::SDK::REST::Payment.find(payment_id)
        transaction = payment.transactions.first
        authorization = transaction.related_resources.first.authorization

        capture = authorization.capture({
            :amount => {
                :currency => "USD",
                :total => authorization.amount.total
            },
            :is_final_capture => true
        })

        self.paypal_responses << capture.to_json
        unless capture.success?
            save
            raise PaymentNotCaptured unless capture.success?
        end

        self.payment_timestamps[:captured] = Time.now
        self.paid = true
        self.status = 'active'
        save
    end

    ## Exceptions
    class PaymentNotAuthorized < StandardError
    end

    class PaymentInfoMissing < StandardError
    end

    class PaymentNotCaptured < StandardError
    end
end