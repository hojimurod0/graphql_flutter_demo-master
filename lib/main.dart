import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

void main() async {
  await initHiveForFlutter();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final HttpLink httpLink = HttpLink("http://10.10.2.80:4000/");

    ValueNotifier<GraphQLClient> client = ValueNotifier(
      GraphQLClient(
        link: httpLink,
        cache: GraphQLCache(),
      ),
    );

    return GraphQLProvider(
      client: client,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: TodosScreen(),
      ),
    );
  }
}

class TodosScreen extends StatefulWidget {
  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final String getTodosQuery = '''
    query {
      todos {
        id
        description
        title
        completed
      }
    }
  ''';

  final String deleteTodoMutation = '''
    mutation DeleteTodo(\$id: ID!) {
      deleteTodo(id: \$id)
    }
  ''';

  final String addTodoMutation = '''
    mutation AddTodo(\$title: String!, \$description: String!, \$completed: Boolean!) {
      addTodo(title: \$title, description: \$description, completed: \$completed) {
        id
        title
        description
        completed
      }
    }
  ''';

  final String updateTodoMutation = '''
    mutation UpdateTodo(\$id: ID!, \$title: String!, \$description: String!, \$completed: Boolean!) {
      updateTodo(id: \$id, title: \$title, description: \$description, completed: \$completed) {
        id
        title

        description
        completed
      }
    }
  ''';

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 114, 153, 220),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 17, 67, 155),
        title: Text(
          "Todos",
          style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.bold,
              color: Colors.amberAccent),
        ),
      ),
      body: Query(
        options: QueryOptions(document: gql(getTodosQuery)),
        builder: (QueryResult result, {fetchMore, refetch}) {
          if (result.hasException) {
            return Center(child: Text("Error: ${result.exception.toString()}"));
          }

          if (result.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          final List todos = result.data?['todos'] ?? [];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];

                      return Card(
                        child: ListTile(
                          leading: Mutation(
                            options: MutationOptions(
                              document: gql(updateTodoMutation),
                              onCompleted: (data) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text("Updated successfully")));
                                refetch?.call();
                              },
                            ),
                            builder: (runMutation, result) {
                              return Checkbox(
                                value: todo['completed'],
                                onChanged: (value) {
                                  runMutation({
                                    "id": todo["id"],
                                    "title": todo["title"],
                                    "description": todo["description"],
                                    "completed": value,
                                  });
                                },
                              );
                            },
                          ),
                          title: Text(todo['description'] ?? "No description"),
                          subtitle: Text(todo['title'] ?? "No title"),
                          trailing: SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Mutation(
                                  options: MutationOptions(
                                    document: gql(updateTodoMutation),
                                    onCompleted: (data) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  "Updated successfully")));
                                      refetch?.call();
                                    },
                                  ),
                                  builder: (runMutation, result) {
                                    return IconButton(
                                      onPressed: () {
                                        titleController.text = todo["title"];
                                        descriptionController.text =
                                            todo["description"];
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: Text("Update Todo"),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(
                                                      controller:
                                                          titleController),
                                                  TextField(
                                                      controller:
                                                          descriptionController),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text("Cancel"),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    runMutation({
                                                      "id": todo["id"],
                                                      "title": titleController
                                                          .text
                                                          .trim(),
                                                      "description":
                                                          descriptionController
                                                              .text
                                                              .trim(),
                                                      "completed":
                                                          todo['completed'],
                                                    });
                                                    titleController.clear();
                                                    descriptionController
                                                        .clear();
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text("Update"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      icon: Icon(Icons.edit),
                                    );
                                  },
                                ),
                                Mutation(
                                  options: MutationOptions(
                                    document: gql(deleteTodoMutation),
                                    onCompleted: (data) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  "Deleted successfully")));
                                      refetch?.call();
                                    },
                                  ),
                                  builder: (runMutation, result) {
                                    return IconButton(
                                      onPressed: () {
                                        runMutation({"id": todo["id"]});
                                      },
                                      icon: Icon(Icons.delete),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AddTodoButton(refetch: refetch),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AddTodoButton extends StatelessWidget {
  final VoidCallback? refetch;

  AddTodoButton({super.key, this.refetch});

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql('''
          mutation AddTodo(\$title: String!, \$description: String!, \$completed: Boolean!) {
            addTodo(title: \$title, description: \$description, completed: \$completed) {
              id
              title
              description
              completed
            }
          }
        '''),
        onCompleted: (data) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Todo added successfully")));
          titleController.clear();
          descriptionController.clear();
          Navigator.pop(context);
          refetch?.call();
        },
      ),
      builder: (runMutation, result) {
        return FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text("Add Todo"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: titleController),
                      TextField(controller: descriptionController),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        runMutation({
                          "title": titleController.text.trim(),
                          "description": descriptionController.text.trim(),
                          "completed": false,
                        });
                      },
                      child: Text("Add"),
                    ),
                  ],
                );
              },
            );
          },
          child: Icon(Icons.add),
        );
      },
    );
  }
}
