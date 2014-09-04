;;; synosaurus.el --- An Emacs frontend for thesauri

;; Copyright (C) 2012  Hans-Peter Deifel

;; Author: Hans-Peter Deifel <hpdeifel@gmx.de>
;; Keywords: wp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Please see the readme

;;; Code:

(require 'button)

(eval-when-compile
  (require 'cl))

(defgroup synosaurus nil "An extensible thesaurus mode"
  :group 'convenience
  :group 'text)

(defcustom synosaurus-choose-method 'ido
  "The method that is provide the user with alternatives.

Valid values are:

  - popup         : Use popup.el to show a nice poopu with alternatives
  - ido           : Use IDO to read an alternative with completion
  - default       : Use normal minibuffer completion."
  :group 'synosaurus
  :type  'symbol
  :options '(popup ido default))

(defcustom synosaurus-backend nil
  "The backend that should be used to query the thesaurus

Build in backends are openthesaurus and wordnet"
  :group 'synosaurus
  :type  'function)

(defun synosaurus-internal-lookup (word)
  (if synosaurus-backend
      (funcall synosaurus-backend word)
    (error "No thesaurus lookup function specified")))

(defun synosaurus-strip-properties (string)
  (set-text-properties 0 (length string) nil string)
  string)

(defun synosaurus-guess-default ()
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (synosaurus-strip-properties (thing-at-point 'word))))

(defvar synosaurus-history nil)

(defun synosaurus-interactive ()
  (let* ((default (synosaurus-guess-default))
         (res (read-string (if default
                               (format "Word (default %s): " default)
                             "Word: ")
                           nil 'synosaurus-history)))
    (list
     (if (not (string= res ""))
         res
       default))))

(defun synosaurus-button-action (arg)
  (synosaurus-lookup (button-label arg)))

(defvar synosaurus-list-mode-map
  (let ((map (copy-keymap button-buffer-map)))
    (set-keymap-parent map special-mode-map)
    map))

(define-derived-mode synosaurus-list-mode special-mode "Synosaurus")

(defun synosaurus-lookup (word)
  "Lookup a word in the thesaurus.

Queries the user for a word and looks it up in a thesaurus using
`synosaurus-backend'.

The resulting synonym list will be shown in a new buffer, where
the words are clickable to look them up instead of the original
word."
  (interactive (synosaurus-interactive))
  (let ((inhibit-read-only t))
    (with-current-buffer (get-buffer-create "*Synonyms List*")
      (erase-buffer)
      (insert
       (propertize (format "Synonyms of %s:\n\n" word)
                   'face 'success))
      (flet ((ins (syn)
                  (unless (string= word syn)
                    (insert " ")
                    (insert-text-button syn
                                        'action 'synosaurus-button-action)
                    (insert "\n"))))
        (dolist (syn (synosaurus-internal-lookup word))
          (if (not (listp syn))
              (ins syn)
            (dolist (syn2 syn)
              (ins syn2))
            (insert "\n"))))
      (goto-char (point-min))
      (condition-case nil (forward-button 1 t nil)
        (error nil))
      (synosaurus-list-mode)))
  (display-buffer "*Synonyms List*"))

(defun synosaurus-choose (list)
  (let ((completion-prompt "Replacement: "))
   (case synosaurus-choose-method
     (popup
      (unless (require 'popup nil t)
        (error "Please install popup.el to use the popup choose-method"))
      (popup-menu* list))
     (ido
      (require 'ido)
      (ido-completing-read completion-prompt list))
     (otherwise (completing-read completion-prompt list)))))

(defun synosaurus-choose-and-replace ()
  "Replace the word under the cursor by a synonyme.

Look up the word in the thesaurus specified by
`synosaurus-backend', let the user choose an alternative
and replace the original word with that."
  (interactive "")
  (let* ((word (synosaurus-guess-default))
         (syns
          (loop for syn in (synosaurus-internal-lookup word)
                if (listp syn) append syn
                else append (list syn)))
         (res (synosaurus-choose syns)))
    (if (use-region-p)
        (delete-region (region-beginning) (region-end))
      (delete-region (beginning-of-thing 'word)
                     (end-of-thing 'word)))
    (insert res)))

(provide 'synosaurus)
;;; synosaurus.el ends here
