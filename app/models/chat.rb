# Turbo Stream handeled by controllers.
# Read more about it @ https://discuss.hotwired.dev/t/authentication-and-devise-with-broadcasts/1752/16
class Chat < ApplicationRecord
  # Relationships
  has_many :messages, -> { oldest }, dependent: :destroy
  has_many :chat_users, dependent: :destroy
  has_many :users, through: :chat_users

  # Validations
  validates :is_private, inclusion: { in: [true, false] }

  default_scope { order(updated_at: :desc) }
  # Scopes
  scope :dms_for, lambda { |user|
    where(is_private: true)
      .joins(:chat_users)
      .where(chat_users: { user_id: user.id })
      .order(updated_at: :desc)
      .distinct
  }

  scope :with_users, -> { includes(:users) }

  scope :groups_for, lambda { |user|
    includes(:users)
    where(is_private: false)
      .where(users: { id: user.id })
      .references(:users)
      .order(updated_at: :desc)
  }

  scope :latest_updated, lambda {
    where(updated_at: (DateTime.now - 5.minutes)...DateTime.now)
      .joins(:chat_users)
      .where('chats.updated_at > chat_users.last_seen_at')
  }

  def self.ransackable_attributes(_auth_object = nil)
    ["name"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["users"]
  end

  # Methods
  def self.between(user1, user2)
    u1_chats = Chat.dms_for(user1).map(&:id)
    u2_chats = Chat.dms_for(user2).map(&:id)
    (u1_chats & u2_chats).first # intersection / common chats
  end

  def email_chat_reply_email(reply_domain:)
    "chat+#{signed_id(purpose: :chat_reply)}@#{reply_domain}"
  end

  def other_users(user)
    (users.all - [user])
  end

  def first_other_users(user)
    other_users(user).first
  end

  def self.find_by_email_chat_reply_id(email:, reply_domain:)
    # capture the id of the chat from the email
    capture = email.match(/^chat\+(?<id>[^@]*)@#{reply_domain}$/)
    Chat.find_signed(capture[:id], purpose: :chat_reply) if capture.present?
  end
end
