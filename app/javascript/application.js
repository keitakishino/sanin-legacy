// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { toggleEditForm } from "./utils/toggle_edit_form"

// Make toggleEditForm available globally for inline onclick handlers
window.toggleEditForm = toggleEditForm
