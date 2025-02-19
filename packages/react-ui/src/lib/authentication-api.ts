import { api } from '@/lib/api';
import {
  CreateOtpRequestBody,
  ResetPasswordRequestBody,
  VerifyEmailRequestBody,
} from '@activepieces/ee-shared';
import {
  AuthenticationResponse,
  ClaimTokenRequest,
  FederatedAuthnLoginResponse,
  ProjectRole,
  SignInRequest,
  SignUpRequest,
  SwitchPlatformRequest,
  SwitchProjectRequest,
  ThirdPartyAuthnProviderEnum,
} from '@activepieces/shared';
import { AuthenticationError } from '@anthropic-ai/sdk/error';
import { Interface } from 'readline';
interface AuthenticateInRequest {
  Authorization: string; // For the authorization token or header
  "device-type": string; // For specifying the device type
  "gtWeb": string;
  "gtApp": string;
}
export const authenticationApi = {
  signIn(request: SignInRequest) {
    return api.post<AuthenticationResponse>(
      '/v1/authentication/sign-in',
      request,
    );
  },
  signUp(request: SignUpRequest) {
    return api.post<AuthenticationResponse>(
      '/v1/authentication/sign-up',
      request,
    );
  },
  getFederatedAuthLoginUrl(providerName: ThirdPartyAuthnProviderEnum) {
    return api.get<FederatedAuthnLoginResponse>(`/v1/authn/federated/login`, {
      providerName,
    });
  },
  me() {
    return api.get<ProjectRole | null>('/v1/project-members/role');
  },
  claimThirdPartyRequest(request: ClaimTokenRequest) {
    return api.post<AuthenticationResponse>(
      '/v1/authn/federated/claim',
      request,
    );
  },
  sendOtpEmail(request: CreateOtpRequestBody) {
    return api.post<void>('/v1/otp', request);
  },
  resetPassword(request: ResetPasswordRequestBody) {
    return api.post<void>('/v1/authn/local/reset-password', request);
  },
  verifyEmail(request: VerifyEmailRequestBody) {
    return api.post<void>('/v1/authn/local/verify-email', request);
  },
  switchProject(request: SwitchProjectRequest) {
    return api.post<AuthenticationResponse>(
      `/v1/authentication/switch-project`,
      request,
    );
  },
  switchPlatform(request: SwitchPlatformRequest) {
    return api.post<AuthenticationResponse>(
      `/v1/authentication/switch-platform`,
      request,
    );
  },
  // gtAuthentication(request: AuthenticateInRequest) {
  //   return api.post<void>(
  //     `${import.meta.env.VITE_GT_API_BASE_URL}/v1/activepieces/validate-user`,
  //     { "device-type": "WEB" }, // Request body
  //     {
  //       headers: {
  //         Authorization: request?.toString(), // Headers
  //       },
  //     }
  //   );
  // }
  gtAuthentication: async (request: AuthenticateInRequest): Promise<AuthenticationResponse> => {
    // Make your API call
    console.log("hello_request:====", request)
    if (!request.gtWeb && !request.gtApp) {
      throw new Error('Error in request URI');
    }
    const response = await fetch(
      `${request.gtApp}/api/v1/activepieces/validate-user`,
      {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: request.Authorization, // Add Authorization header
        "device-type": request["device-type"], // Add device-type header
      },
    });

    if (!response.ok) {
      throw new Error('Authentication failed');
    }

    // Parse and return the response as `AuthenticationResponse`
    const data: AuthenticationResponse = await response.json();
    return data;
  },
}