;;; nngnorb.el --- Gnorb backend for Gnus

;; This file is in the public domain.

;; Author: Eric Abrahamsen <eric@ericabrahamsen.net.>

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a backend for supporting Gnorb-related stuff. I'm going to
;; regret this, I know.

;; It started off just with wanting to collect all the gnus links in a
;; subtree, and display all the messages in an ephemeral group. But it
;; doesn't seem possible to create ephemeral groups without
;; associating them with a server, and which server would that be?
;; Nnir also provides a nice interface to creating ephemeral groups,
;; but again, it relies on a server parameter to know which nnir
;; engine to use, and if you try to fake it it still craps out.

;; So this file is a copy-pasta from nnnil.el -- I'm trying to keep
;; this as simple as possible. Right now it does nothing but serving
;; as a place to hang ephemeral groups made with nnir searches of
;; message from the rest of your gnus installation. Enjoy.

;;; Code:

(eval-and-compile
  (require 'nnheader)
  (require 'nnir))

(defvar nngnorb-status-string "")

(gnus-declare-backend "nngnorb" 'none)

(add-to-list 'nnir-method-default-engines '(nngnorb . gnorb))

(add-to-list 'nnir-engines
	     '(gnorb nnir-run-gnorb
		     ((gnorb-nnir-string . "Org Agenda tags search string: "))))

(defun nnir-run-gnorb (query server &optional group)
  "Run the actual search for messages to display. See nnir.el for
some details of how this gets called.

As things stand, the query string can be given as one of two
different things. First is the ID string of an Org heading,
prefixed with \"id+\". This was probably a bad choice as it could
conceivably look like an org tags search string. Fix that later.
If it's an ID, then the entire subtree text of that heading is
scanned for gnus links, and all the linked messages are displayed
in an ephemeral group.

Otherwise, the query string can be a tags match string, a la the
Org agenda tags search. All headings matched by this string will
be scanned for gnus messages, and those messages displayed."
  (save-excursion
    (let ((q-string (cdr (assq 'query query)))
	  subtrees links subtree-text vectors)
      (if (string-match "id\\+\\([[:alnum:]-]+\\)$" q-string)
	  (with-demoted-errors "Error: %S"
	    (org-id-goto (match-string 1 q-string))
	    (push (move-marker
		   (make-marker)
		   (org-element-property :begin (org-element-at-point)))
		  subtrees))
	(org-map-entries
	 (lambda ()
	   (push
	    (move-marker (make-marker)
			 (org-element-property :begin
					       (org-element-at-point)))
	    subtrees))
	 q-string
	 'agenda))
      (when subtrees
	(with-current-buffer (get-buffer-create nnir-tmp-buffer)
	  (erase-buffer)
	  (dolist (m subtrees)
	    (save-excursion
	      (org-pop-to-buffer-same-window (marker-buffer m))
	      (goto-char m)
	      (move-marker m nil)
	      (setq subtree-text
		    (buffer-substring-no-properties
		     (point)
		     (org-element-property
		      :end
		      (org-element-at-point)))))
	    (insert subtree-text)
	    (insert "\n"))
	  (goto-char (point-min))
	  (setq links (delete-dups (gnorb-scan-links
				    (point-max) 'gnus))))
	(dolist (m (plist-get links :gnus) (nreverse vectors))
	  (let (server-group msg-id artno)
	    (setq m (org-link-unescape m))
	    (if (not (string-match "\\`\\([^#]+\\)\\(#\\(.*\\)\\)?" m))
		(error "Error in Gnus link"))
	    (setq server-group (match-string 1 m)
		  msg-id (match-string 3 m))
	    ;; I swear just finding the `gnus-request-head' function
	    ;; was a trial in itself. But I've only tried it with
	    ;; nnimap -- does it work for other backends?
	    (setq artno (cdr (gnus-request-head msg-id server-group)))
	    (when (> artno 0)
	      (push (vector server-group artno 100) vectors))))))))

(defvar nngnorb-status-string "")

(defun nngnorb-retrieve-headers (articles &optional group server fetch-old)
  (with-current-buffer nntp-server-buffer
    (erase-buffer))
  'nov)

(defun nngnorb-open-server (server &optional definitions)
  t)

(defun nngnorb-close-server (&optional server)
  t)

(defun nngnorb-request-close ()
  t)

(defun nngnorb-server-opened (&optional server)
  t)

(defun nngnorb-status-message (&optional server)
  nnnil-status-string)

(defun nngnorb-request-article (article &optional group server to-buffer)
  (setq nnnil-status-string "No such group")
  nil)

(defun nngnorb-request-group (group &optional server fast info)
  (let (deactivate-mark)
    (with-current-buffer nntp-server-buffer
      (erase-buffer)
      (insert "411 no such news group\n")))
  (setq nnnil-status-string "No such group")
  nil)

(defun nngnorb-close-group (group &optional server)
  t)

(defun nngnorb-request-list (&optional server)
  (with-current-buffer nntp-server-buffer
    (erase-buffer))
  t)

(defun nngnorb-request-post (&optional server)
  (setq nngnorb-status-string "Read-only server")
  nil)

(provide 'nngnorb)

;;; nnnil.el ends here