export const OpponentCursor = {
  mounted() {
    this.$ghost = document.createElement("div");
    this.$ghost.className =
      "ghost-cursor pointer-events-none absolute border-2 border-yellow-400/70 z-50 transition-all duration-100";

    this.el.appendChild(this.$ghost);

    this.currentRow = null;
    this.currentCol = null;

    this.handleEvent("opponent_hover", ({ row, col }) => {
      this.currentRow = row;
      this.currentCol = col;
      this.updateCursorPosition();
    });
  },

  updated() {
    if (this.$ghost.parentElement !== this.el) {
      this.el.appendChild(this.$ghost);
    }
    this.updateCursorPosition();
  },

  isActive() {
    return this.el.dataset.active === "true";
  },

  updateCursorPosition() {
    if (!this.isActive() || this.currentRow === null || this.currentCol === null) {
      this.$ghost.style.opacity = "0";
      return;
    }

    const $cell = this.el.querySelector(
      `[data-row="${this.currentRow}"][data-col="${this.currentCol}"]`
    );

    if (!$cell) {
      this.$ghost.style.opacity = "0";
      return;
    }

    this.$ghost.style.opacity = "1";
    this.$ghost.style.left = `${$cell.offsetLeft}px`;
    this.$ghost.style.top = `${$cell.offsetTop}px`;
    this.$ghost.style.width = `${$cell.offsetWidth}px`;
    this.$ghost.style.height = `${$cell.offsetHeight}px`;
  },
};
