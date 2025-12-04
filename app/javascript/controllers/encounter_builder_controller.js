import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "nodesContainer",
    "nodeTemplate",
    "optionTemplate",
    "associationsContainer",
    "associationTemplate",
    "branchesContainer",
    "branchTemplate"
  ]

  connect() {
    this.nodeCounter = this.nodesContainerTarget.children.length
    this.associationCounter = this.hasAssociationsContainerTarget ? this.associationsContainerTarget.children.length : 0
  }

  addNode(event) {
    event.preventDefault()
    const index = this.nodeCounter++
    const template = this.nodeTemplateTarget.innerHTML.replace(/__NODE_INDEX__/g, index)
    this.appendTemplate(this.nodesContainerTarget, template)

    if (this.hasBranchesContainerTarget && this.hasBranchTemplateTarget) {
      const branchTemplate = this.branchTemplateTarget.innerHTML.replace(/__NODE_INDEX__/g, index)
      this.appendTemplate(this.branchesContainerTarget, branchTemplate)
    }
  }

  addOption(event) {
    event.preventDefault()
    const button = event.currentTarget
    const nodeIndex = button.dataset.nodeIndex
    if (!nodeIndex) return

    const list = this.element.querySelector(`[data-option-list='${nodeIndex}']`)
    if (!list) return

    const optionIndex = list.children.length
    const template = this.optionTemplateTarget.innerHTML
      .replace(/__NODE_INDEX__/g, nodeIndex)
      .replace(/__OPTION_INDEX__/g, optionIndex)
    this.appendTemplate(list, template)
  }

  addAssociation(event) {
    event.preventDefault()
    if (!this.hasAssociationsContainerTarget) return

    const index = this.associationCounter++
    const template = this.associationTemplateTarget.innerHTML.replace(/__ASSOC_INDEX__/g, index)
    this.appendTemplate(this.associationsContainerTarget, template)
  }

  removeBlock(event) {
    event.preventDefault()
    const block = event.currentTarget.closest("[data-removable]")
    if (!block) return

    const nodeIndex = block.dataset.nodeIndex
    block.remove()

    if (nodeIndex && this.hasBranchesContainerTarget) {
      const branch = this.branchesContainerTarget.querySelector(`[data-branch='${nodeIndex}']`)
      if (branch) branch.remove()
    }
  }

  appendTemplate(target, html) {
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html.trim()
    const element = wrapper.firstElementChild
    target.appendChild(element)
  }
}
