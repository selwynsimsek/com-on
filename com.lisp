#|
 This file is a part of com-on
 (c) 2020 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.com-on)

(defvar *initialized* NIL)

(defun create (class instance)
  (init)
  (with-deref (com :pointer)
    (com:create-instance class (cffi:null-pointer) com:CLSCTX-ALL instance com)))

(defun release (pointer)
  (cffi:foreign-funcall-pointer
   (cffi:mem-aref (com:vtbl pointer) :pointer 2)
   ()
   :pointer pointer
   :unsigned-long))

(defmacro with-com ((var init) &body body)
  `(let ((,var ,init))
     (unwind-protect
          (progn ,@body)
       (release ,var))))

(defmacro define-comfun ((struct method &rest options) return-type &body args)
  (let* ((*print-case* (readtable-case *readtable*))
         (structg (gensym "STRUCT"))
         (name (intern (format NIL "~a-~a" struct method))))
    `(progn
       (declaim (inline ,name))
       (defun ,name (,structg ,@(mapcar #'first args))
         (cffi:foreign-funcall-pointer
          (,(intern (format NIL "%~a" name))
           (com:vtbl ,structg))
          ,options
          :pointer ,structg
          ,@(loop for (name type) in args
                  collect type collect name)
          ,return-type)))))

(defmacro define-comstruct (name &body methods)
  (let ((methods (list* `(query-interface (uid :pointer) (out :pointer))
                        `(add-ref :unsigned-long)
                        `(release :unsigned-long)
                        methods)))
    `(progn
       (cffi:defcstruct (,name :conc-name ,(format NIL "%~a-" name))
         ,@(loop for method in methods
                 collect (list (first method) :pointer)))

       ,@(loop for (method return . args) in methods
               ;; Default to hresult return
               do (when (consp return)
                    (push return args)
                    (setf return 'com:hresult))
               collect `(define-comfun (,name ,method) ,return
                          ,@args)))))

(defun init ()
  (unless *initialized*
    (cffi:load-foreign-library 'com:ole32)
    (check-hresult
     (com:initialize (cffi:null-pointer) :multi-threaded))
    (setf *initialized* T)))

(defun shutdown ()
  (when *initialized*
    (com:uninitialize)
    (setf *initialized* NIL)))
