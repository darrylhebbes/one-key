;;; one-key-dir.el --- Functions for quickly navigating directory trees with one-key menus

;; Filename: one-key-dir.el
;; Description: Functions for quickly navigating directory trees with one-key menus
;; Author: Joe Bloggs <vapniks@yahoo.com>
;; Maintainer: Joe Bloggs <vapniks@yahoo.com>
;; Copyright (C) 2010, Joe Bloggs, all rights reserved.
;; Created: 2010-09-21 17:23:00
;; Version: 0.1
;; Last-Updated: 2010-09-21 17:23:00
;;           By: Joe Bloggs
;; URL: http://www.emacswiki.org/emacs/download/one-key-dir.el
;; Keywords: one-key, directories
;; Compatibility: GNU Emacs 24.0.50.1
;;
;; Features that might be required by this library:
;;
;; one-key.el
;;

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary: 
;; 
;; Functions for quickly navigating directory trees with one-key menus
;; 
;; `one-key-dir-visit' can be used to navigate a directory tree and apply functions 
;;  to files. It's not an interactive function, so you should write wrapping functions
;;  yourself. You can refer to `one-key-dir/find-file' as an example, which can be
;;  used to navigate to and open a file using one-key.
;;
;; NOTE: hidden files and directories are excluded from the one-key menus generated, 
;; as are backup files (files whose names begin with "~"). This is to keep the number of
;; items in the one-key menus small enough so that enough keys can be generated.
;; Also note that if the number of items is large they may not all fit in the viewing area
;; of the one-key menu. In this case you can use the UP/DOWN arrow keys to scroll the menu 
;; up and down to view the rest of the items.

;;; Installation:
;;
;; Put one-key-dir.el in a directory in your load-path, e.g. ~/.emacs.d/
;; You can add a directory to your load-path with the following line in ~/.emacs
;; (add-to-list 'load-path (expand-file-name "~/elisp"))
;; where ~/elisp is the directory you want to add 
;; (you don't need to do this for ~/.emacs.d - it's added by default).
;;
;; Add the following to your ~/.emacs startup file.
;;
;; (require 'one-key-dir)

;;; Customize:
;; There is nothing to customize.

;;; TODO:
;;
;; Handle large directories by splitting items between several alists and passing these to `one-key-menu' as a list
;; of alists/symbols (once that functionality is added to `one-key-menu').
;; Allow different methods for allocating keys to menu items (e.g. using first unused letter of each item).
;; Auto-highlight menu items based on filetype using dired colour scheme.
;; Add "sort by filetype" to sort list.

;;; Change log:
;;	
;; 2010/09/21
;;      * First released.
;; 

;;; Require
(require 'one-key)

;;; Code:
(defface one-key-dir-file-name 
  `((default (:background ,(if (featurep 'dired+)
                               (face-foreground 'diredp-file-name nil t)
                             (face-foreground 'dired-ignored nil t)))))
  "*Face used for file names."
  :group 'one-key-dir)

(defface one-key-dir-directory
  `((default (:background ,(if (featurep 'dired+)
                               (face-foreground 'diredp-dir-priv nil t)
                             (face-foreground 'dired-directory nil t)))))
  "*Face used for directories."
  :group 'one-key-dir)

(defface one-key-dir-symlink
  `((default (:background ,(if (featurep 'dired+)
                               (face-foreground 'diredp-symlink nil t)
                             (face-foreground 'dired-symlink nil t)))))
  "*Face used for symlinks."
  :group 'one-key-dir)

(defvar one-key-dir/max-lisp-eval-depth 2000
  "The `max-lisp-eval-depth' when using one-key-dir.el.
Because one-key related functions don't exit until the one-key menu buffer is killed. 
Setting this to a large number can avoid error of `Lisp nesting exceeds max-lisp-eval-depth")

(defvar one-key-dir-current-filename nil
  "Current file's name which is visited by one-key.")

(defvar one-key-dir-current-dir nil
  "Current directory which is visited by one-key.")

(defvar one-key-dir-sort-method-alist '((name . (lambda (a b) (string< a b)))
                                        (extension . (lambda (a b)
                                                       (flet ((get-ext (file-name) ; function to get file extension
                                                                       (car (cdr (split-string file-name "\\.")))))
                                                         (let ((filea (file-name-nondirectory a))
                                                               (fileb (file-name-nondirectory b)))
                                                           (cond ((file-directory-p a) t)
                                                                 ((file-directory-p b) nil)
                                                                 (t (string< (get-ext filea) (get-ext fileb))))))))
                                        (size . (lambda (a b)
                                                  (let ((attriba (file-attributes a))
                                                        (attribb (file-attributes b)))
                                                    (> (nth 7 attriba) (nth 7 attribb)))))
                                        (time-accessed . (lambda (a b)
                                                           (let* ((attriba (file-attributes a))
                                                                  (attribb (file-attributes b))
                                                                  (x (nth 4 attriba))
                                                                  (y (nth 4 attribb)))
                                                             (or (> (car x) (car y))
                                                                 (and (= (car x) (car y))
                                                                      (> (cadr x) (cadr y)))))))
                                        (time-modified . (lambda (a b)
                                                           (let* ((attriba (file-attributes a))
                                                                  (attribb (file-attributes b))
                                                                  (x (nth 5 attriba))
                                                                  (y (nth 5 attribb)))
                                                             (or (> (car x) (car y))
                                                                 (and (= (car x) (car y))
                                                                      (> (cadr x) (cadr y)))))))
                                        (time-changed . (lambda (a b)
                                                          (let* ((attriba (file-attributes a))
                                                                 (attribb (file-attributes b))
                                                                 (x (nth 6 attriba))
                                                                 (y (nth 6 attribb)))
                                                            (or (> (car x) (car y))
                                                                (and (= (car x) (car y))
                                                                     (> (cadr x) (cadr y))))))))
  "An alist of sort predicates to use for sorting directory listings.
Each element is a cons cell in the form (NAME . PREDICATE) where NAME is a symbol naming the predicate and PREDICATE
is a function which takes two items as arguments and returns non-nil if the first item should come before the second
in the menu.")

(defvar one-key-dir-current-sort-method 'extension
  "The current method used to sort the items in the `one-key-dir' directory listing")

(defgroup one-key-dir nil
  "Filesystem navigation using `one-key'."
  :group 'one-key)

(defcustom one-key-dir-back-to-topdir-key ?^
  "Key that will be used to return to the parent directory.
This should not be a letter or number key."
  :group 'one-key-dir
  :type '(character :validate (lambda (w) (let ((val (widget-value w)))
                                            (if (memq val (append one-key-default-menu-keys
                                                                  (list one-key-dir-current-directory-key)))
                                                (progn (widget-put w :error "That key is already used! Try another")
                                                       w))))))

(defcustom one-key-dir-current-directory-key ?.
  "Key that will be used to open the current directory.
This should not be a letter or number key."
  :group 'one-key-dir
  :type '(character :validate (lambda (w) (let ((val (widget-value w)))
                                            (if (memq val (append one-key-default-menu-keys
                                                                  (list one-key-dir-back-to-topdir-key)))
                                                (progn (widget-put w :error "That key is already used! Try another")
                                                       w))))))

(defcustom one-key-dir/topdir "~/"
  "The fixed top level dir that `one-key-dir-visit' can explore the subdirs of,
but can't go above this dir."
  :group 'one-key-dir
  :type 'directory)

(defcustom one-key-dir/max-items-per-page 40
  "The maximum number of menu items to display on each page."
  :group 'one-key-dir
  :type '(number :match (lambda (w val)
                          (> val 0))))

(defcustom one-key-dir-special-keybindings
  '(("ESC" "Quit and close menu window" (lambda nil (keyboard-quit) nil))
    ("<C-escape>" "Quit, but keep menu window open"
     (lambda nil (setq keep-window-p t) nil))
    ("<C-menu>" "Toggle menu persistence"
     (lambda nil (if match-recursion-p
                     (setq match-recursion-p nil
                           miss-match-recursion-p nil)
                   (setq match-recursion-p t
                         miss-match-recursion-p t))))
    ("<menu>" "Toggle menu display" (lambda nil (one-key-menu-window-toggle) t))
    ("<left>" "Change to next menu" (lambda nil (if menu-number
                                                     (progn
                                                       (setq menu-number
                                                             (if (equal menu-number 0)
                                                                 (1- (length info-alists))
                                                               (1- menu-number)))
                                                       (setq one-key-menu-call-first-time t))) t))
    ("<right>" "Change to previous menu" (lambda nil (if menu-number
                                                        (progn
                                                          (setq menu-number
                                                                (if (equal menu-number (1- (length info-alists)))
                                                                    0 (1+ menu-number)))
                                                          (setq one-key-menu-call-first-time t))) t))
    ("<up>" "Scroll/move up one line" (lambda nil (one-key-scroll-or-move-up full-list) t))
    ("<down>" "Scroll/move down one line" (lambda nil (one-key-scroll-or-move-down full-list) t))
    ("<prior>" "Scroll menu down one page" (lambda nil (one-key-menu-window-scroll-down) t))
    ("<next>" "Scroll menu up one page" (lambda nil (one-key-menu-window-scroll-up) t))
    ("<f1>" "Toggle this help buffer" (lambda nil (if (get-buffer-window "*Help*")
                                                      (kill-buffer "*Help*")
                                                    (one-key-show-help special-keybindings)) t))
    ("<f2>" "Toggle column/row ordering of items"
     (lambda nil (if one-key-column-major-order
                        (setq one-key-column-major-order nil)
                      (setq one-key-column-major-order t))
       (setq one-key-menu-call-first-time t) t))
    ("<f3>" "Sort items by next method"
     (lambda nil (one-key-dir-sort-by-next-method) t))
    ("<C-f3>" "Sort items by previous method"
     (lambda nil (one-key-dir-sort-by-next-method t) t))
    ("<f4>" "Reverse order of items"
     (lambda nil (one-key-reverse-item-order info-alists full-list menu-number) t))
    ("<f5>" "Limit items to those matching regexp"
     (lambda nil (setq filter-regex (read-regexp "Regular expression"))
       (setq one-key-menu-call-first-time t) t))
    ("<f6>" "Highlight items matching regexp"
     (lambda nil (let ((regex (read-regexp "Regular expression"))
                       (bgcolour (read-color "Colour: ")))
                   (one-key-highlight-matching-items
                    info-alist full-list bgcolour
                    (lambda (item) (string-match regex (cdar item))))) t))
    ("<C-f10>" "Add a menu"
     (lambda nil (one-key-add-menus) nil))
    ("<C-S-f10>" "Remove this menu"
     (lambda nil (one-key-delete-menu) t))
    ("<f11>" "Reposition item (with arrow keys)"
     (lambda nil (let ((key (single-key-description
                             (read-key "Enter key of item to be moved"))))
                   (setq one-key-current-item-being-moved key)
                   (setq one-key-menu-call-first-time t)) t)))

  "An list of special keys, their labels and associated functions that apply to `one-key-dir' menus.
Each item in the list contains (in this order):

  1) A string representation of the key (as returned by `single-key-description').

  2) A short description of the associated action.
     This description will be displayed in the *One-Key* buffer.

  3) A function for performing the action. The function takes no arguments but may use dynamic binding to
     read and change some of the values in the initial `one-key-menu' function call.
     The function should return t to display the `one-key' menu again after the function has finished,
     or nil to close the menu.

These keys and functions apply only to `one-key-dir' menus and are not displayed with the menu specific keys.
They are for general tasks such as displaying command help, scrolling the window, sorting menu items, etc."
  :group 'one-key-dir
  :type '(repeat (list (string :tag "Keybinding" :help-echo "String representation of the keybinding for this action")
                       (string :tag "Description" :help-echo "Description to display in help buffer")
                       (function :tag "Function" :help-echo "Function for performing action. See description below for further details."))))

(defun one-key-dir-sort-by-next-method (&optional prev)
  "Sort the `one-key-dir' menu by the method in `one-key-dir-sort-method-alist' after `one-key-dir-current-sort-method'.
If PREV is non-nil then sort by the previous method instead."
  (let* ((nextmethod (car (one-key-get-next-alist-item one-key-dir-current-sort-method
                                                       one-key-dir-sort-method-alist
                                                       prev)))
         (dir (car (string-split this-name " ")))
         (pos (position (concat dir " (1)") names :test 'equal)))
    (setq one-key-dir-current-sort-method nextmethod)
    (let* ((sortedlists (one-key-dir/build-menu-alist dir :initial-sort-method nextmethod))
           (nlists (length sortedlists)))
      (loop for n from 1 to nlists
            for nstr = (number-to-string n)
            for pos = (position (concat dir " (" nstr ")") names :test 'equal)
            do (replace info-alists sortedlists
                        :start1 pos :end1 (1+ pos)
                        :start2 (1- n) :end2 n)))
    (setq one-key-menu-call-first-time t)
    (one-key-menu-window-close)))

(defun* one-key-dir-visit (dir &key
                               (filefunc (lambda nil
                                           (interactive)
                                           (find-file one-key-dir-current-filename)))
                               (dirfunc (lambda nil
                                          (interactive)
                                          (find-file one-key-dir-current-filename)))
                               filename-map-func
                               (exclude-regex "^\\."))
  "Visit DIR using one-key.
For each sub-dir of DIR, the associated command will be `(one-key-dir-visit sub-dir filefunc)',
for each file under DIR, the associated command will be `(funcall filefunc)' (so filefunc should not require any arguments).
In FILEFUNC, `one-key-dir-current-filename' can be used to do operations on the current file.
The optional FILENAME-MAP-FUNC specifies a function to be called on each file name,
it has one argument (string), the original file name, and returns a string, the
new file name which will be displayed in the one-key menu.
DIR should either be `one-key-dir/topdir' or a directory under `one-key-dir/topdir' 
in the directory tree."
  (unless (file-directory-p dir)
    (error "one-key-dir-visit called with a non-directory"))
  (unless (functionp filefunc)
    (error "one-key-dir-visit called with a non-function."))
  (unless (one-key-dir/legal-dir-p dir)
    (error "one-key-dir-visit called with an illegal directory."))
  (setq one-key-dir-current-dir dir)
  (let ((old-max-lisp-eval-depth max-lisp-eval-depth))
    (setq max-lisp-eval-depth one-key-dir/max-lisp-eval-depth)
    (unwind-protect
	(let* ((dir-alists (one-key-dir/build-menu-alist
                                             dir :filefunc filefunc :dirfunc dirfunc
                                             :filename-map-func filename-map-func
                                             :exclude-regex exclude-regex))
               (nummenus (length dir-alists))
               (menunames (one-key-dir-make-names dir nummenus)))
          (one-key-menu menunames dir-alists)))
    (setq max-lisp-eval-depth old-max-lisp-eval-depth)))

(defun* one-key-dir/build-menu-alist (dir &key
                                          (filefunc (lambda nil
                                                      (interactive)
                                                      (find-file one-key-dir-current-filename)))
                                          (dirfunc (lambda nil
                                                     (interactive)
                                                     (find-file one-key-dir-current-filename)))
                                          filename-map-func
                                          (exclude-regex "^\\.")
                                          (initial-sort-method 'extension))
  "Build `one-key-menu' items lists for directory DIR.
Each element of the returned list has the following form: ((KEY . NAME) . FUNCTION).
Where FUNCTION is a function that may call FILEFUNC or DIRFUNC depending on whether the item corresponds to a file
or directory. If FILENAME-MAP-FUNC is non-nil it should be a function that takes a single file or directory name
as argument and returns a label for the menu item. Otherwise the name of the file/directory will be used for the label.
If EXCLUDE-REGEX is non-nil it should be a regular expression which will be matched against each items name (before being
put through FILENAME-MAP-FUNC). Any matching items will be omitted from the results.

Only the first `one-key-dir/max-items-per-page' items (excluding \"..\" and \".\") will be placed in each list.
If there are no more than `one-key-dir/max-items-per-page' items, then a single list will be returned, otherwise several
lists will be returned (as list of lists). These lists can be navigated from the `one-key' menu using the arrow keys."
  (unless (file-directory-p dir)
    (error "one-key-dir/build-key-name-list called with a non-directory."))
  (flet ( ;; temp function to indicate whether to exclude an item or not
         (exclude (str) (or (equal (file-name-nondirectory str) "..")
                            (equal (file-name-nondirectory str) ".")
                            (and exclude-regex
                                 (string-match exclude-regex
                                               (file-name-nondirectory str))))))
    (let* ((dirname (file-name-as-directory (file-truename dir)))
           (sortfunc (cdr (assoc initial-sort-method one-key-dir-sort-method-alist)))
           (items (sort (remove-if 'exclude (directory-files dirname t)) sortfunc))
           (cmdfunc (lambda (item)
                      (if (file-directory-p item)
                          `(lambda nil  ; command for directories
                            (interactive)
                            (one-key-dir-visit
                             ,item :filefunc ,filefunc
                             :dirfunc ,dirfunc
                             :filename-map-func ,filename-map-func
                             :exclude-regex ,exclude-regex))
                           `(lambda nil ; command for files
                              (interactive)
                              (setq one-key-dir-current-filename
                                    ,(file-truename item))
                              (funcall ,filefunc)))))
           (commands (mapcar cmdfunc items))
           (descfunc (lambda (item)
                       (let ((name (file-name-nondirectory item)))
                       (if (file-directory-p item)
                           (propertize (concat name "/") 'face 'one-key-dir-directory)
                         (if (file-symlink-p item) (propertize name 'face 'one-key-dir-symlink)
                           (propertize name 'face 'one-key-dir-file-name))))))
           (descriptions (mapcar descfunc items))
           (menu-alists (one-key-create-menu-lists commands descriptions nil
                                                   one-key-dir/max-items-per-page)))
      menu-alists)))

(defun one-key-dir-make-names (dir nummenus)
  "Return list of NUMMENUS menu names for directory DIR."
  (loop for num from 1 to nummenus
        collect (concat (file-name-as-directory (file-truename dir))
                        " (" (number-to-string num) ")")))



(defun one-key-dir/subdirs (directory &optional file?)
  "Return subdirs or files of DIRECTORY according to FILE?.
If file? is t then return files, otherwise return directories.
Hidden and backup files and directories are not included."
  (remove-if (lambda (file)
               (or (string-match "^\\." (file-name-nondirectory file))
                   (string-match "~$" (file-name-nondirectory file))
                   (if file? (file-directory-p file)
                     (not (file-directory-p file)))))
             (directory-files directory t)))

(defun one-key-dir/legal-dir-p (dir)
  "Return t if DIR is `one-key-dir/topdir' or a descendant of `one-key-dir/topdir'."
  (or (string= (file-name-as-directory (file-truename dir))
	       (file-name-as-directory (file-truename one-key-dir/topdir)))
      (one-key-dir/descendant-p dir)))

(defun one-key-dir/descendant-p (dir)
  "Return t if DIR is a descendant of `one-key-dir/topdir'."
  (let ((topdir-name (file-name-as-directory (file-truename one-key-dir/topdir)))
	(dir-name (file-name-as-directory (file-truename dir))))
    (and (not (string= topdir-name dir-name))
	 (= (- (abs (compare-strings topdir-name 0 nil dir-name 0 nil)) 1) (length topdir-name)))))
;	 (string-prefix-p topdir-name dir-name))))

;; Here is an example of how to use one-key-dir-visit:
(defun one-key-dir/find-file (topdir)
  "Use one-key-dir-visit to navigate directories and then visit the selected file."
  (interactive (list (if (featurep 'ido)
                         (ido-read-directory-name "Directory to use: " default-directory)
                       (read-directory-name "Directory to use: " default-directory))))
  (one-key-dir-visit topdir))

;; Redefine `one-key-add-menu' so that directories can also be added.
;; Use the following dummy variable for user variable selection.
(defvar one-key-menu-one-key-dir-alist nil
  "Dummy variable used by `one-key-add-menu' to indicate that the user wants to add a `one-key-dir' menu.")

;; Set the title string format and special keybindings for existing `one-key-dir' menus
(one-key-add-to-alist 'one-key-types-of-menu
                      (list (lambda (name)
                              "This type accepts the path to any existing directory"
                              (let ((dir (car (string-split name " "))))
                                             (if (file-directory-p dir) dir)))
                            (lambda (name)
                              (let* ((alists (one-key-dir/build-menu-alist name))
                                     (names (one-key-dir-make-names name (length alists))))
                                (cons names alists)))
                            (lambda nil (format "Files sorted by %s (%s first). Press <f1> for help.\n"
                                           one-key-dir-current-sort-method
                                           (if one-key-column-major-order "columns" "rows")))
                            'one-key-dir-special-keybindings) t)
;; Set menu-alist, title string and special keybindings for new `one-key-dir' menus, prompting the user for the directory
(one-key-add-to-alist 'one-key-types-of-menu
                      (list "directory menu"
                            (lambda (name)
                              (let* ((dir (if (featurep 'ido)
                                              (ido-read-directory-name "Directory to use: " default-directory)
                                            (read-directory-name "Directory to use: " default-directory)))
                                     (menulists (one-key-dir/build-menu-alist dir))
                                     (nummenus (length menulists)))
                                (cons (one-key-dir-make-names dir nummenus) menulists)))
                            (lambda nil (format "Files sorted by %s (%s first). Press <f1> for help.\n"
                                                one-key-dir-current-sort-method
                                                (if one-key-column-major-order "columns" "rows")))
                            'one-key-dir-special-keybindings) t)

(provide 'one-key-dir)
;;; one-key-dir.el ends here
