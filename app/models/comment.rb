# Comentário de uma Publication. Premissa inicial: raiz + um nível de respostas.
class Comment < ApplicationRecord
  BODY_LENGTH = 1..2000

  belongs_to :publication
  belongs_to :author, class_name: "User", inverse_of: :comments
  belongs_to :parent, class_name: "Comment", optional: true, inverse_of: :replies
  belongs_to :removed_by, class_name: "User", optional: true

  has_many :replies, class_name: "Comment", foreign_key: :parent_id, inverse_of: :parent,
           dependent: :restrict_with_exception
  has_many :comment_likes, dependent: :destroy
  has_many :content_reports, dependent: :restrict_with_exception

  normalizes :body, with: ->(body) { body.strip }

  validates :body, presence: true, length: { in: BODY_LENGTH }
  validates :removal_reason, presence: true, if: :removed?
  validates :removed_by, presence: true, if: :removed?
  validate :parent_rules
  validate :immutable_references, on: :update

  scope :roots, -> { where(parent_id: nil) }
  scope :chronological, -> { order(:created_at, :id) }
  scope :visible_content, -> { where(deleted_at: nil, removed_at: nil) }

  def deleted?
    deleted_at.present?
  end

  def removed?
    removed_at.present?
  end

  def hidden?
    deleted? || removed?
  end

  def root?
    parent_id.nil?
  end

  private

    def parent_rules
      return if parent.nil?

      errors.add(:parent, :self_reference) if parent_id == id && id.present?
      errors.add(:parent, :other_publication) if parent.publication_id != publication_id
      errors.add(:parent, :reply_depth) unless parent.root?
    end

    def immutable_references
      %i[publication_id author_id parent_id].each do |attribute|
        errors.add(attribute, :immutable) if will_save_change_to_attribute?(attribute)
      end
    end
end
