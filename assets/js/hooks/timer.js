export const Timer = {
  mounted() {
    this.$sec = this.el.querySelector("[data-role='seconds']")
    this.$rect = this.el.querySelector("[data-role='progress']")
    this.durationS = Number(this.el.dataset.durationS || 30)
    this.deadlineMs = Date.now() + Number(this.el.dataset.remainingMs)

    this.render = this.render.bind(this)
    this.render()
    this.interval = setInterval(this.render, 1000)
  },

  render() {
    const remainingMs = Math.max(this.deadlineMs - Date.now(), 0)
    const remainingSeconds = Math.ceil(remainingMs / 1000)
    const progressOffset = 100 - (remainingMs / (this.durationS * 1000)) * 100

    if (this.$sec) this.$sec.textContent = remainingSeconds
    if (this.$rect) this.$rect.style.strokeDashoffset = Math.max(0, Math.min(100, progressOffset));

    if (remainingMs <= 0 && this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  },

  updated() {
    this.deadlineMs = Date.now() + Number(this.el.dataset.remainingMs)
    if (!this.interval) {
      this.interval = setInterval(this.render, 1000)
    }
  },

  destroyed() {
    clearInterval(this.interval)
  },
}
