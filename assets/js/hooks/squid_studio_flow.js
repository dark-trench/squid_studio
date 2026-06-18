export const SquidStudioFlow = {
  mounted() {
    this.drag = null

    window.requestAnimationFrame(() => this.centerGraph())

    this.el.addEventListener("pointerdown", (event) => {
      if (this.isReadOnly()) {
        return
      }

      const node = event.target.closest("[data-node-id]")

      if (!node || !this.el.contains(node)) {
        return
      }

      const canvasRect = this.el.getBoundingClientRect()
      const nodeRect = node.getBoundingClientRect()

      this.drag = {
        id: node.dataset.nodeId,
        pointerId: event.pointerId,
        offsetX: event.clientX - nodeRect.left,
        offsetY: event.clientY - nodeRect.top,
        canvasLeft: canvasRect.left,
        canvasTop: canvasRect.top,
      }

      node.setPointerCapture(event.pointerId)
      event.preventDefault()
    })

    this.el.addEventListener("pointermove", (event) => {
      if (!this.drag || this.drag.pointerId !== event.pointerId) {
        return
      }

      this.pushEvent("move_node", {
        id: this.drag.id,
        x: Math.round(event.clientX - this.drag.canvasLeft - this.drag.offsetX),
        y: Math.round(event.clientY - this.drag.canvasTop - this.drag.offsetY),
      })
    })

    this.el.addEventListener("pointerup", (event) => {
      if (!this.drag || this.drag.pointerId !== event.pointerId) {
        return
      }

      this.drag = null
    })
  },

  centerGraph() {
    const rect = this.el.getBoundingClientRect()

    if (rect.width <= 0 || rect.height <= 0) {
      window.setTimeout(() => this.centerGraph(), 50)
      return
    }

    this.pushEvent("center_graph", {
      width: Math.round(rect.width),
      height: Math.round(rect.height),
    })
  },

  isReadOnly() {
    return this.el.dataset.readOnly === "true"
  },
}
