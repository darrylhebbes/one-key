;;; one-key-ext.el --- Extension functions for One-key

;; Copyright (C) 2010  

;; Author: 
;; Keywords: 

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

;; `one-key-visit-dir' can be used to navigate directory and apply functions to
;;  files. It's not an interactive function, so you should write wrapping functions
;;  yourself. You can refer to `one-key-print-filename' as an example, which print
;;  current file's name using one-key in minibuffer.

;;; Code:
(require 'one-key)
(require 'one-key-yas)

(defvar one-key-current-filename nil
  "Current file's name which is visited by one-key.")

(defun one-key-visit-dir (dir func)
  "Visit DIR using one-key.
For each sub-dir of DIR, the associated command will be `(one-key-visit-dir sub-dir func)',
for each file under DIR, the associated command will be `(funcall func)'.
In FUNC, `one-key-current-filename' can be used to do operations on current file."
  (unless (file-directory-p dir)
    (error "one-key-visit-dir called with a non-directory"))

  (let ((old-max-lisp-eval-depth max-lisp-eval-depth))
    (setq max-lisp-eval-depth one-key-yas/max-lisp-eval-depth)
    (unwind-protect
	(let* ((dir-name (file-name-as-directory (file-truename dir)))
	       (key-name-list (one-key-ext/build-key-name-list dir))
	       (one-key-menu-ext/dir-alist (one-key-ext/build-menu-alist key-name-list func)))
	  (flet ((one-key-menu-ext-func ()
					(one-key-menu dir-name
						      one-key-menu-ext/dir-alist)))
	    (one-key-menu-ext-func)))
      (setq max-lisp-eval-depth old-max-lisp-eval-depth))
    (setq max-lisp-eval-depth old-max-lisp-eval-depth)))

(defun one-key-ext/build-menu-alist (key-name-list func)
  "Return the menu alist that will be used by One-key.
KEY-NAME-LIST is generated by `one-key-ext/build-key-name-list'.
FUNC is the function that will be applied to normal files."
  (let (menu-alist)
    (dolist (key-name key-name-list)
      (if (fourth key-name)		; A directory
	(push (cons (cons (first key-name) (second key-name))
		    `(lambda ()
		       (interactive)
		       (one-key-visit-dir (third ',key-name) ,func)))
	      menu-alist)
	(push (cons (cons (first key-name) (second key-name))
		    `(lambda ()
		       (interactive)
		       (setq one-key-current-filename (concat (third ',key-name) (second ',key-name)))
		       (funcall ,func)))
	      menu-alist)))
    menu-alist))

(defun one-key-ext/build-key-name-list (dir &optional dont-show-parent)
  "Build the key name list for directory DIR.
Each element of the returned list has the following form:
 (KEY FILE-NAME FULLPATH DIRP)
If optional DONT-SHOW-PARENT is non-nil, there will not be a
\"C-b\" \"Back to parent directory\" item."
  (unless (file-directory-p dir)
    (error "one-key-ext/build-key-name-list called with a non-directory."))

  (let* ((dir-name (file-name-as-directory (file-truename dir)))
	 (sub-dirs (mapcar #'file-name-nondirectory (one-key-ext/subdirs dir)))
	 (files (mapcar #'file-name-nondirectory (one-key-ext/subdirs dir t)))
	 (keys (if dont-show-parent '("q") '("C-b" "q")))
	 (key-name-list nil))

    ;; build key for sub-dirs
    (dolist (sub-dir sub-dirs)
      (let ((key (one-key-yas/generate-key sub-dir keys)))
	(push key keys)
	(push `(,key ,(concat sub-dir "/")
		     ,(concat (file-name-as-directory dir-name) sub-dir)
		     t)
	      key-name-list)))

    ;; build key for files
    (dolist (file files)
      (let ((key (one-key-yas/generate-key file keys)))
	(push key keys)
	(push `(,key ,(file-name-nondirectory (file-truename (concat dir-name file)))
		     ,dir-name nil)
	      key-name-list)))

    ;; Here we push the "C-b"
    (unless dont-show-parent
      (push `("C-b" ,(concat "Back to parent directory: "
			     (file-name-nondirectory (expand-file-name ".." dir)))
	      ,(expand-file-name ".." dir-name) t)
	    key-name-list))
    key-name-list))

(defun one-key-ext/subdirs (directory &optional file?)
  "Return subdirs or files of DIRECTORY according to FILE?."
  (remove-if (lambda (file)
               (or (string-match "^\\."
                                 (file-name-nondirectory file))
                   (string-match "~$"
                                 (file-name-nondirectory file))
                   (if file?
                       (file-directory-p file)
                     (not (file-directory-p file)))))
             (directory-files directory t)))

;;;;;;;;;; example function ;;;;;;;;;;;;;;
(require 'ido)

(defun one-key-print-filename (dir)
  "Print current file's name using one-key in minibuffer."
  (interactive (list (ido-read-directory-name "Directory for root of tree: " default-directory)))
  
  (one-key-visit-dir dir (lambda ()
			   (message "current file name: %s"  one-key-current-filename))))

(provide 'one-key-ext)
;;; one-key-ext.el ends here
