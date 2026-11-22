(in-package #:cl-user)
(defpackage #:rove/core/fixture
  (:use #:cl)
  (:export #:deffixture
           #:with-fixture
           #:with-fixtures
           #:fixture-yield
           #:find-fixture
           #:clear-fixture-caches
           #:*session-fixture-cache*))
(in-package #:rove/core/fixture)

(defvar *fixtures* (make-hash-table :test 'eq))
(defvar *session-fixture-cache* (make-hash-table :test 'eq))
(defvar *suite-fixture-cache* (make-hash-table :test 'eq))

(defclass fixture ()
  ((name :initarg :name :reader fixture-name)
   (scope :initarg :scope :reader fixture-scope)
   (fn :initarg :fn :reader fixture-fn)))

(defun find-fixture (name)
  (or (gethash name *fixtures*)
      (error "No fixture named ~S" name)))

(defun set-fixture (name scope fn)
  (check-type scope (member :test :suite :session))
  (setf (gethash name *fixtures*)
        (make-instance 'fixture :name name :scope scope :fn fn))
  name)

(defun clear-fixture-caches (&key (suite t) (session nil))
  (when suite
    (clrhash *suite-fixture-cache*))
  (when session
    (clrhash *session-fixture-cache*)))

(defun call-with-fixture (name continue)
  (let* ((fx (find-fixture name))
         (scope (fixture-scope fx)))
    (ecase scope
      (:test
       (funcall (fixture-fn fx) continue))
      ((:suite :session)
       (let* ((cache (if (eq scope :suite)
                         *suite-fixture-cache*
                         *session-fixture-cache*))
              (cell (gethash name cache)))
         (if cell
             (funcall continue (car cell))
             ;; Cache the value; skip post-YIELD teardown (use suite TEARDOWN / DEFHOOK).
             (catch 'rove-fixture-cache
               (funcall (fixture-fn fx)
                        (lambda (value)
                          (setf (gethash name cache) (list value))
                          (funcall continue value)
                          (throw 'rove-fixture-cache value))))))))))

(defun fixture-yield-names ()
  "Function names DEFFIXTURE binds to the yield continuation.
FIXTURE-YIELD is exported. YIELD is interned in the package the fixture is
read in, so a bare (YIELD x) works without ROVE exporting a generic YIELD
that clashes with other libraries (e.g. SXQL). ROVE/CORE/FIXTURE::YIELD
keeps old package-qualified callers working."
  (remove-duplicates
   (list 'fixture-yield
         'yield
         (intern (symbol-name 'yield) *package*))))

(defmacro deffixture (name (&key (scope :test)) &body body)
  "Define a fixture. Call YIELD (or FIXTURE-YIELD) with the value; code after
the call is teardown.

SCOPE is :test (default), :suite (once per package suite), or :session
(once per ROVE:RUN)."
  (let ((continue (gensym "CONTINUE"))
        (names (fixture-yield-names)))
    `(eval-when (:load-toplevel :execute)
       (set-fixture ',name ,scope
                    (lambda (,continue)
                      (flet ,(loop for fname in names
                                   collect `(,fname (&optional value)
                                              (funcall ,continue value)))
                        (declare (ignorable ,@(loop for fname in names
                                                    collect `(function ,fname))))
                        ,@body)))
       ',name)))

(defmacro with-fixture ((var name) &body body)
  `(call-with-fixture ',name (lambda (,var) ,@body)))

(defmacro with-fixtures (bindings &body body)
  (if (null bindings)
      `(progn ,@body)
      (destructuring-bind (binding . rest) bindings
        (unless (and (consp binding) (second binding))
          (error "WITH-FIXTURES binding must be (VAR NAME), got ~S" binding))
        `(with-fixture (,(first binding) ,(second binding))
           (with-fixtures ,rest
             ,@body)))))
