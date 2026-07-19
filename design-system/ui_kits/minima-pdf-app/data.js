
const docs = [
  { id: 1, title: "Q3 Research Notes.pdf", pages: 142, progress: 62, tag: "Research" },
  { id: 2, title: "Contract — NDA Draft.pdf", pages: 8, progress: 100, tag: "Contracts" },
  { id: 3, title: "Distributed Systems, 3rd Ed.pdf", pages: 612, progress: 18, tag: "Reference" },
  { id: 4, title: "Faculty Meeting Minutes.pdf", pages: 4, progress: 0, tag: "Admin" },
  { id: 5, title: "Grant Proposal — Draft 4.pdf", pages: 26, progress: 45, tag: "Research" },
  { id: 6, title: "Thesis — Chapter 2.pdf", pages: 51, progress: 88, tag: "Research" },
];

function LibraryData() { return docs; }
window.LibraryData = LibraryData;
