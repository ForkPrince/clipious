import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:clipious/search/models/search_date.dart';
import 'package:clipious/search/models/search_duration.dart';
import 'package:clipious/search/models/search_sort_by.dart';

import '../../states/search_filter.dart';

class SearchFiltersButton extends StatelessWidget {
  final SearchFiltersState initialFilters;
  final Function(SearchFiltersState) onChanged;

  const SearchFiltersButton({
    super.key,
    required this.initialFilters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locals = AppLocalizations.of(context)!;
    return IconButton(
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: false,
          builder: (BuildContext context) {
            return BlocProvider(
              create: (context) => SearchFiltersCubit(initialFilters),
              child: BlocBuilder<SearchFiltersCubit, SearchFiltersState>(
                builder: (context, state) {
                  final cubit = context.read<SearchFiltersCubit>();
                  onDateChanged(SearchDate? newValue) {
                    cubit.setDate(newValue);
                  }

                  onDurationChanged(SearchDuration? newValue) {
                    cubit.setDuration(newValue);
                  }

                  onSortByChanged(SearchSortBy? newValue) {
                    cubit.setSortBy(newValue);
                  }

                  return AlertDialog(
                    content: SingleChildScrollView(
                      child: ListBody(children: <Widget>[
                        Text(locals.searchUploadDate),
                        RadioGroup<SearchDate>(
                          groupValue: state.date,
                          onChanged: onDateChanged,
                          child: Column(
                            children: SearchDate.values
                                .map((value) => RadioListTile<SearchDate>(
                                      title: Text(value.getLabel(locals)),
                                      value: value,
                                    ))
                                .toList(),
                          ),
                        ),
                        Text(locals.searchDuration),
                        RadioGroup<SearchDuration>(
                          groupValue: state.duration,
                          onChanged: onDurationChanged,
                          child: Column(
                            children: SearchDuration.values
                                .map((value) => RadioListTile<SearchDuration>(
                                      title: Text(value.getLabel(locals)),
                                      value: value,
                                    ))
                                .toList(),
                          ),
                        ),
                        Text(locals.searchSortBy),
                        RadioGroup<SearchSortBy>(
                          groupValue: state.sortBy,
                          onChanged: onSortByChanged,
                          child: Column(
                            children: SearchSortBy.values
                                .map((value) => RadioListTile<SearchSortBy>(
                                      title: Text(value.getLabel(locals)),
                                      value: value,
                                    ))
                                .toList(),
                          ),
                        ),
                      ]),
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text(locals.cancel),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text(locals.ok),
                        onPressed: () {
                          onChanged(state);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
      icon: const Icon(Icons.filter_list_alt),
    );
  }
}
