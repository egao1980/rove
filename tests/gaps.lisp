(defpackage #:rove/tests/gaps
  (:use #:cl #:rove)
  (:import-from #:rove/core/marks
                #:test-marks
                #:eval-mark-expr
                #:test-selected-by-marks-p
                #:*mark-expr*)
  (:import-from #:rove/core/diff #:format-value-diff #:maybe-value-diff)
  (:import-from #:rove/reporter/junit #:write-junit-report #:junit-reporter)
  (:import-from #:rove/core/result #:passed-test))
(in-package #:rove/tests/gaps)

(deftest (marked-slow :marks (:slow))
  (ok t))

(deftest (marked-fast :marks (:fast))
  (ok t))

(deftest mark-metadata
  (ok (equal '(:slow) (test-marks 'marked-slow)))
  (ok (eval-mark-expr :slow '(:slow)))
  (ng (eval-mark-expr :slow '(:fast)))
  (ok (eval-mark-expr '(not :slow) '(:fast)))
  (ok (eval-mark-expr '(or :slow :fast) '(:fast)))
  (ng (eval-mark-expr '(and :slow :fast) '(:slow)))
  (let ((*mark-expr* :slow))
    (ok (test-selected-by-marks-p 'marked-slow))
    (ng (test-selected-by-marks-p 'marked-fast)))
  (let ((*mark-expr* '(not :slow)))
    (ng (test-selected-by-marks-p 'marked-slow))
    (ok (test-selected-by-marks-p 'marked-fast))))

(defvar *fx-count* 0)
(defvar *fx-teardown* 0)

(deffixture bump-counter ()
  (incf *fx-count*)
  (yield *fx-count*)
  (incf *fx-teardown*))

(deffixture suite-token (:scope :suite)
  (yield :once))

(deftest fixture-test-scope
  (let ((*fx-count* 0)
        (*fx-teardown* 0))
    (with-fixture (n bump-counter)
      (ok (= n 1)))
    (ok (= *fx-count* 1))
    (ok (= *fx-teardown* 1))
    (with-fixtures ((a bump-counter) (b bump-counter))
      (ok (= a 2))
      (ok (= b 3)))
    (ok (= *fx-teardown* 3))))

(deftest fixture-suite-scope
  (with-fixture (a suite-token)
    (with-fixture (b suite-token)
      (ok (eq a :once))
      (ok (eq b :once)))))

(deftest value-diff-text
  (let ((diff (format-value-diff "a" "b")))
    (ok (search "expected:" diff))
    (ok (search "actual:" diff)))
  (ok (search "expected:" (maybe-value-diff '(equal x y) '("aa" "bb"))))
  (ng (maybe-value-diff '(plusp n) '(1))))

(deftest timeout-records-failure
  (let ((name (intern (string (gensym "TO")) :rove/tests/gaps))
        (rove:*debug-on-error* nil))
    (eval `(deftest (,name :timeout 0.05)
             (sleep 1)))
    (unwind-protect
         (ng (rove:run-test name :style :none))
      (rove:remove-test name))))

(deftest junit-xml-shape
  (let ((reporter (make-instance 'junit-reporter
                                 :stream (make-broadcast-stream))))
    (rove/core/stats:record reporter
                            (make-instance 'passed-test
                                           :name "ok-case"
                                           :description "ok"))
    (let ((xml (with-output-to-string (s)
                 (write-junit-report s reporter :suite-name "gaps"))))
      (ok (search "<?xml" xml))
      (ok (search "testsuite" xml))
      (ok (search "ok-case" xml)))))

(deftest shard-indices
  (let ((tests '(a b c d))
        (shard-0 '())
        (shard-1 '()))
    (loop for test in tests
          for i from 0
          if (zerop (mod i 2))
            do (push test shard-0)
          else
            do (push test shard-1))
    (ok (equal '(c a) shard-0))
    (ok (equal '(d b) shard-1))))
