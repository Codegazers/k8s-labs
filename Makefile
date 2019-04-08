recreate:
	vagrant destroy -f || true
	rm -rf tmp/* || true
	vagrant up k8s1 k8s2
