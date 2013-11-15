PROGRAM=ladder

$(PROGRAM): ladder.ml
	ocamlfind ocamlopt -o $(PROGRAM) ladder.ml

.PHONY: clean
clean:
	rm -f $(PROGRAM) *.cmi *.cmx *.o

