import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:crm_interface/modules/customers/models/create_customer.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'POST sends a typed body and parses the short creation response',
    () async {
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      final request = CreateCustomerRequest(
        fullName: 'Тестовый клиент',
        dateOfBirth: DateTime(1992, 3, 15),
        acquisitionSourceId: 8,
        gender: CustomerGender.female,
        contacts: const [
          CreateCustomerContact(type: ContactType.phone, value: '+79162331045'),
        ],
      );
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/customers');
            expect(options.queryParameters, isEmpty);
            expect(options.data, request.toApi());
            expect(options.data['date_of_birth'], '1992-03-15');
            expect(options.data.containsKey('created_by_employee_id'), isFalse);
            expect(options.data.containsKey('registration_method'), isFalse);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'id': 42,
                  'full_name': 'Тестовый клиент',
                  'status': 'active',
                  'created_at': '2026-10-07T12:00:00Z',
                },
              ),
            );
          },
        ),
      );
      final created = await CustomersRepository(client).createCustomer(request);
      expect(created.id, 42);
      expect(created.createdAt, DateTime.utc(2026, 10, 7, 12));
    },
  );

  test(
    'loads active source, branch and employee options from catalog APIs',
    () async {
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      final paths = <String>{};
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            expect(options.queryParameters, isEmpty);
            handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {
                    'id': 8,
                    options.path == '/employees' ? 'full_name' : 'name':
                        'Тестовый выбор',
                  },
                ],
              ),
            );
          },
        ),
      );
      final options = await CustomersRepository(client).getCreationOptions();
      expect(paths, {'/acquisition-sources', '/branches', '/employees'});
      expect(options.sources.single.id, 8);
      expect(options.branches.single.name, 'Тестовый выбор');
      expect(options.employees.single.name, 'Тестовый выбор');
    },
  );

  test('shows safe conflict/validation/permission messages without server internals', () {
    CustomerRequestException error(int status, dynamic detail) {
      final request = RequestOptions(path: '/customers');
      return CustomerRequestException.fromDio(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: request,
            statusCode: status,
            data: {'detail': detail},
          ),
        ),
      );
    }

    expect(
      error(409, {'message': 'Основной телефон уже занят'}).message,
      'Основной телефон уже занят',
    );
    expect(
      error(422, {
        'message': 'Ошибка проверки',
        'errors': [
          {'message': 'Некорректный контакт'},
        ],
      }).message,
      'Некорректный контакт',
    );
    expect(error(403, null).message, contains('Недостаточно прав'));
    expect(
      error(500, {'message': 'Traceback secret'}).message,
      isNot(contains('secret')),
    );
  });

  test(
    'rejects malformed success without suggesting a blind duplicate POST',
    () async {
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'id': 42},
              ),
            );
          },
        ),
      );
      await expectLater(
        CustomersRepository(client).createCustomer(
          CreateCustomerRequest(
            fullName: 'Тестовый клиент',
            dateOfBirth: DateTime(2000),
            acquisitionSourceId: 8,
            contacts: const [
              CreateCustomerContact(
                type: ContactType.email,
                value: 'client@example.com',
              ),
            ],
          ),
        ),
        throwsA(
          isA<CustomerRequestException>().having(
            (e) => e.message,
            'message',
            contains('Проверьте список'),
          ),
        ),
      );
    },
  );

  test(
    'reads customers from a paginated response and sends limit/offset',
    () async {
      final client = ApiClient(SessionStore());
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/customers');
            expect(options.queryParameters, {'limit': 1, 'offset': 2});
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'items': [
                    {
                      'id': 7,
                      'full_name': 'Тестовый клиент',
                      'gender': null,
                      'date_of_birth': null,
                      'status': 'active',
                      'primary_contact': null,
                      'acquisition_source_name': 'Сайт',
                      'responsible': null,
                    },
                  ],
                  'total': 3,
                  'limit': 1,
                  'offset': 2,
                },
              ),
            );
          },
        ),
      );
      final customers = await CustomersRepository(client)
          .getCustomers(limit: 1, offset: 2);
      expect(customers.single.id, 7);
      expect(customers.single.fullName, 'Тестовый клиент');
    },
  );

  test('accepts an empty page and rejects an invalid items field', () async {
    final client = ApiClient(SessionStore());
    var invalid = false;
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'items': invalid ? null : <dynamic>[],
                'total': 0,
                'limit': 50,
                'offset': 0,
              },
            ),
          );
        },
      ),
    );
    final repository = CustomersRepository(client);
    expect(await repository.getCustomers(), isEmpty);
    invalid = true;
    await expectLater(
      repository.getCustomers(),
      throwsA(isA<CustomerRequestException>()),
    );
  });
}
