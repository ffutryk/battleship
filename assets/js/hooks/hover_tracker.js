export const HoverTracker = {
  mounted() {
    this.lastKey = null;

    this.onHover = (event) => {
      const $cell = event.target.closest("[data-row]");
      if (!$cell) return;

      const row = Number($cell.dataset.row);
      const col = Number($cell.dataset.col);
      const key = `${row}:${col}`;

      if (key === this.lastKey) return;
      this.lastKey = key;

      this.pushEvent("hover_cell", { row, col });
    };

    this.el.addEventListener("mouseover", this.onHover);
  },

  destroyed() {
    this.el.removeEventListener("mouseover", this.onHover);
  },
};
