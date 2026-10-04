import { Controller } from "@hotwired/stimulus"

// Feedback visual; as mesmas exigências são verificadas pelo servidor.
export default class extends Controller {
  static targets = ["password", "confirmation", "rule", "meter", "feedback", "confirmationFeedback"]

  connect() { this.update() }

  update() {
    const password = this.passwordTarget.value
    const checks = {
      length: [...password].length >= 8,
      upper: /\p{Lu}/u.test(password),
      lower: /\p{Ll}/u.test(password),
      number: /[0-9]/.test(password),
      symbol: /[^\p{L}\p{N}\s]/u.test(password),
      bytes: password.length > 0 && new TextEncoder().encode(password).length <= 72
    }
    this.ruleTargets.forEach(rule => {
      const valid = checks[rule.dataset.rule]
      rule.dataset.valid = String(valid)
      rule.querySelector(".password-rule-mark").textContent = valid ? "✓" : "·"
      rule.querySelector("[data-rule-status]").textContent = valid ? "atendido" : "pendente"
    })
    const count = Object.values(checks).filter(Boolean).length
    this.meterTarget.style.width = `${count / 6 * 100}%`
    this.meterTarget.dataset.complete = String(count === 6)
    this.feedbackTarget.textContent = !password ? "Crie uma senha que atenda aos requisitos abaixo." : count === 6 ? "Todos os requisitos da senha foram atendidos." : `${count} de 6 requisitos atendidos.`
    const confirmation = this.confirmationTarget.value
    const same = confirmation && confirmation === password
    this.confirmationTarget.setCustomValidity(confirmation && !same ? "As senhas precisam ser iguais." : "")
    this.confirmationFeedbackTarget.textContent = !confirmation ? "Repita a mesma senha." : same ? "As senhas coincidem." : "As senhas ainda não coincidem."
  }
}
