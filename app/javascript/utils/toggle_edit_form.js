/**
 * Toggle the visibility of an edit form row.
 * When opening: shows form and hides mobile expansion row.
 * When closing: hides form (preserves input values, doesn't reset).
 *
 * @param {string} formId - DOM ID of the edit form row (e.g., 'edit_form_trade_card_offer_1')
 * @param {string} expandId - DOM ID of the mobile expansion row (e.g., 'expand_trade_card_offer_1')
 */
export function toggleEditForm(formId, expandId) {
  const formRow = document.getElementById(formId);

  if (!formRow) return;

  // Check if form is currently hidden
  if (formRow.style.display === 'none' || formRow.style.display === '') {
    // Show the form
    formRow.style.display = 'table-row';
    // Hide the mobile expansion row
    const expandRow = document.getElementById(expandId);
    if (expandRow) {
      expandRow.style.display = 'none';
    }
  } else {
    // Hide the form (without resetting it, so input values are preserved)
    formRow.style.display = 'none';
  }
}
