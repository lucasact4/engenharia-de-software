# Formato comum das opções de seleção; a validação continua no backend.
SelectOption = Data.define(:value, :label, :description, :disabled) do
  def self.from_enum(scope, value, disabled: false)
    new(
      value: value.to_s,
      label: I18n.t("enums.#{scope}.#{value}.label"),
      description: I18n.t("enums.#{scope}.#{value}.description"),
      disabled: disabled
    )
  end

  def self.from_catalog(entry, value: entry.id)
    new(value: value, label: entry.name, description: entry.description, disabled: !entry.active?)
  end

  def to_h
    { value: value, label: label, description: description, disabled: disabled }
  end
end
