part of 'failures.dart';

final class RouteArgumentFailure extends Failure {
  const RouteArgumentFailure([super.message = 'Invalid route argument'])
      : super(code: 'ROUTE_ARG_ERROR');
}
