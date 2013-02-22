module Fundraiser
  class Contribution < ActiveRecord::Base

    Stripe.api_key = Fundraiser::Settings.stripe_secret_key

    attr_accessible :amount, :email, :reference, :transaction, :name, :stripeToken, :stripe_id

    serialize :request_params

    before_create :create_stripe_user

    validates :name,        presence: true
    validates :email,       presence: true
    validates :stripeToken, presence: true

    state_machine :state, :initial => :pending do
      state :pending
      state :charged

      before_transition on: :charge do |contribution, transition|
        contribution.stripe_charge
      end

      event :charge do
        transition pending: :charged
      end
    end


    def self.create_from_amazon_ipn(params)
      create(
        :email => params["buyerEmail"],
        :reference => params["referenceId"],
        :request_params => params,
        :amount => amazon_amount_to_cents(params["transactionAmount"])
      )
    end

    def self.amazon_amount_to_cents(amount_with_currency)
      amount = amount_with_currency.split(' ').last
      (amount.to_f * 100).to_i
    end

    def self.total_contributed
      sum(:amount) / 100
    end

    def human_amount
      self.amount / 100
    end

    def create_stripe_user
      token = self.stripeToken
      customer = Stripe::Customer.create(
        :card => token,
        :description => "#{self.name} -  #{self.email}"
      )
      self.stripe_id = customer.id
    rescue Stripe::CardError => e
      logger.error "Stripe error while creating customer: #{e}"
      errors.add :base, "There was a problem with your credit card."
      false
    end

    def stripe_charge
      Stripe::Charge.create(
          :amount => self.amount,
          :currency => "usd",
          :customer => self.stripe_id
      )
    end



  end
end
