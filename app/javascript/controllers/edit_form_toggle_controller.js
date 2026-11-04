import { Controller } from "@hotwired/stimulus"

// カード明細の編集フォーム行の開閉。
// 開くときはモバイルの展開行を閉じる。閉じるときはフォームを消すだけで、
// 入力値はリセットしない（もとの window.toggleEditForm の挙動をそのまま移したもの）。
//
//   <button type="button"
//           data-controller="edit-form-toggle"
//           data-edit-form-toggle-form-value="edit_form_xxx"
//           data-edit-form-toggle-expand-value="expand_xxx"
//           data-action="click->edit-form-toggle#toggle">
export default class extends Controller {
  static values = { form: String, expand: String }

  toggle() {
    const formRow = document.getElementById(this.formValue)
    if (!formRow) return

    if (formRow.style.display === "none" || formRow.style.display === "") {
      formRow.style.display = "table-row"
      const expandRow = document.getElementById(this.expandValue)
      if (expandRow) expandRow.style.display = "none"
    } else {
      formRow.style.display = "none"
    }
  }
}
