// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Toggle the visibility of an edit form row.
// When opening: shows form and hides mobile expansion row.
// When closing: hides form (preserves input values, doesn't reset).
window.toggleEditForm = function(formId, expandId) {
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
