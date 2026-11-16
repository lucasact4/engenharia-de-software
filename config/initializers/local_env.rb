# Somente em desenvolvimento: carrega variáveis de config/local_env.yml (fora do Git) sem sobrescrever o ENV.
# Útil para chaves locais, como as de push (SGU_VAPID_*), sem exportá-las no terminal.
if Rails.env.development?
  local_env = Rails.root.join("config/local_env.yml")
  if local_env.exist?
    YAML.safe_load_file(local_env).to_h.each { |key, value| ENV[key.to_s] ||= value.to_s }
  end
end
