const BOARD_SIZE = 10;
const HORIZONTAL = [0, 1];
const VERTICAL = [1, 0];

function inBounds(row, col) {
  return row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE;
}

function segmentCoords(row, col, orientation, length) {
  const [dRow, dCol] = orientation;
  return Array.from({ length }, (_, i) => [row + dRow * i, col + dCol * i]);
}

export const FleetPlacement = {
  mounted() {
    this.fleet = JSON.parse(this.el.dataset.fleet);
    this.placedShips = [];
    this.currentCoords = null;
    this.orientation = HORIZONTAL;

    this.$confirmBtn = document.getElementById("confirm-btn");
    this.$rotateBtn = document.getElementById("rotate-btn");
    this.$remainingCount = document.getElementById("remaining-count");

    this.$board = this.el;

    this.$board.addEventListener("mouseover", (e) => this.onHover(e));
    this.$board.addEventListener("mouseleave", () => this.clearPreview());
    this.$board.addEventListener("click", (e) => this.onClick(e));

    if (this.$confirmBtn) this.bindButton(this.$confirmBtn, "Enter", () => this.onConfirm());
    if (this.$rotateBtn) this.bindButton(this.$rotateBtn, "r", () => this.onRotate());

    this.updateCount();
  },

  currentShip() {
    return this.fleet[0];
  },

  getPreviewLength() {
    if (this.hasShipsLeft()) {
      return this.fleet[0].length;
    }

    return this.placedShips.at(-1).length;
  },

  currentLength() {
    if (!this.currentShip()) return this.placedShips.at(-1).length;
    return this.currentShip().length;
  },

  hasShipsLeft() {
    return this.fleet.length > 0;
  },

  onHover(event) {
    const $cell = event.target.closest("[data-row]");
    if ($cell) this.preview($cell);
  },

  onClick(event) {
    const $cell = event.target.closest("[data-row]");
    if (!$cell || !this.hasShipsLeft()) return;

    const row = Number($cell.dataset.row);
    const col = Number($cell.dataset.col);

    if (this.isValidPlacement(row, col)) this.placeShip(row, col);
  },

  onRotate() {
    this.orientation = this.orientation === HORIZONTAL ? VERTICAL : HORIZONTAL;

    if (this.currentCoords) {
      const [row, col] = this.currentCoords;
      const $cell = this.cellAt(row, col);
      if ($cell) this.preview($cell);
    }
  },

  onConfirm() {
    if (!this.hasShipsLeft()) {
      this.pushEvent("confirm_placement", { ships: this.placedShips });
    }
  },

  preview($originCell) {
    this.clearPreview();

    const row = Number($originCell.dataset.row);
    const col = Number($originCell.dataset.col);
    this.currentCoords = [row, col];

    const segment = this.segmentAt(row, col);
    const previewClass = this.isValidSegment(segment) ? "valid" : "invalid";

    segment.forEach(([r, c]) => {
      this.cellAt(r, c)?.classList.add("hover", previewClass);
    });
  },

  clearPreview() {
    this.$board.querySelectorAll(".hover").forEach(($cell) => {
      $cell.classList.remove("hover", "valid", "invalid");
    });
  },

  placeShip(row, col) {
    const segment = this.segmentAt(row, col);
    const sprites = this.currentShip().sprites;

    segment.forEach(([r, c], index) => {
      const $cell = this.cellAt(r, c);
      $cell.dataset.occupied = "true";
      const $sprite = this.createCellSprite(sprites[index], index, segment.length);
      $cell.appendChild($sprite);
    });

    this.placedShips.push(segment);
    this.fleet.shift();
    this.clearPreview();
    this.updateCount();

    if (this.$confirmBtn) this.$confirmBtn.disabled = this.hasShipsLeft();
  },

  createCellSprite(spriteSrc, segmentIndex, segmentLength) {
    const $img = document.createElement("img");
    $img.src = spriteSrc;

    if (segmentLength === 1) {
      $img.className = "inset-0 w-full h-full object-cover pointer-events-none";
      return $img;
    }

    const isHorizontal = this.orientation === HORIZONTAL;

    const center =
      segmentLength % 2 === 0
        ? segmentLength / 2 - 0.5
        : Math.floor(segmentLength / 2);

    const distance = Math.abs(segmentIndex - center);
    const base = segmentLength % 2 === 0 ? 2 : 0;
    const offset = (base + distance * 4) * (segmentIndex < center ? 1 : -1);

    const x = isHorizontal ? offset : 0;
    const y = isHorizontal ? 0 : offset;

    $img.className = "inset-0 w-full h-full object-cover pointer-events-none";
    $img.style.transform = `translate(${x}px, ${y}px)${isHorizontal ? "" : " rotate(90deg)"}`;

    return $img;
  },

  segmentAt(row, col) {
    return segmentCoords(row, col, this.orientation, this.currentLength());
  },

  isValidSegment(segment) {
    if (!this.hasShipsLeft()) return false;

    return segment.every(([r, c]) => {
      if (!inBounds(r, c)) return false;
      const $cell = this.cellAt(r, c);
      return $cell && $cell.dataset.occupied !== "true";
    });
  },

  isValidPlacement(row, col) {
    return this.isValidSegment(this.segmentAt(row, col));
  },

  cellAt(row, col) {
    return this.$board.querySelector(`[data-row="${row}"][data-col="${col}"]`);
  },

  updateCount() {
    if (this.$remainingCount) this.$remainingCount.textContent = this.fleet.length;
  },

  bindButton($btn, key, fn) {
    window.addEventListener("keydown", (event) => {
      if (event.key.toUpperCase() === key.toUpperCase() && !event.repeat) {
        $btn.classList.add("is-active");
        fn?.();
      }
    });

    window.addEventListener("keyup", (event) => {
      if (event.key.toUpperCase() === key.toUpperCase()) {
        $btn.classList.remove("is-active");
      }
    });

    $btn.addEventListener("click", fn);
  },
};
