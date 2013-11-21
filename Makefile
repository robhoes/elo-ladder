PROGRAM=ladder

$(PROGRAM): ladder.ml
	ocamlfind ocamlopt -package cmdliner -linkpkg -o $(PROGRAM) ladder.ml

.PHONY: clean
clean:
	rm -f $(PROGRAM) *.cmi *.cmx *.o

