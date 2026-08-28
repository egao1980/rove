;;;; Packager 0.16.0 skip-catalog also skipped <pkg>:latest. Owning-repo
;;;; token can write the package repo. Remove after cl-repository#32 is on
;;;; main (canned publish.lisp writes anchors even on 0.16.0).
(let* ((system (or (uiop:getenv "CL_REPO_SYSTEM")
                   (uiop:getenv "PKG_SYSTEM")
                   "rove"))
       (version (or (let ((v (uiop:getenv "PKG_VERSION")))
                      (and v (plusp (length v)) v))
                    (asdf:component-version (asdf:find-system system))))
       (namespace (string-downcase (or (uiop:getenv "OCI_NAMESPACE")
                                       "egao1980/cl-systems")))
       (auth (cl-oci-client/auth:make-auth-config
              :username (or (uiop:getenv "GITHUB_ACTOR") "x-access-token")
              :password (or (uiop:getenv "GITHUB_TOKEN")
                            (error "GITHUB_TOKEN required"))))
       (reg (cl-oci-client/registry:make-registry "https://ghcr.io" :auth auth))
       (sys-repo (format nil "~a/rove" namespace)))
  (format t "~&; ci: write ~a:latest -> ~a~%" sys-repo version)
  (cl-repository-packager/publisher::ensure-system-name-anchor
   reg sys-repo "rove" "rove" version))
