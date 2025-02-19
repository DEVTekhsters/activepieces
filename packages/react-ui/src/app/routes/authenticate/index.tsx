import { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  ApEdition,
  ApFlagId,
  AuthenticationResponse,
  ErrorCode,
  isNil,
  SignInRequest,
} from '@activepieces/shared';

import { t } from 'i18next';
import { formatUtils } from '@/lib/utils';
import { Static, Type } from '@sinclair/typebox';
import { HttpError, api } from '@/lib/api';
import { useMutation } from '@tanstack/react-query';
import { authenticationApi } from '@/lib/authentication-api';
import { authenticationSession } from '@/lib/authentication-session';
import CryptoJS from 'crypto-js';
import { RedirectPage } from '../redirect';
import { Loader } from 'lucide-react';
interface AuthenticateInRequest {
  Authorization: string; // For the authorization token or header
  "device-type": string; // For specifying the device type
  "gtWeb": string;
  "gtApp": string;
}

const SignInSchema = Type.Object({
  email: Type.String({
    pattern: formatUtils.emailRegex.source,
    errorMessage: t('Email is invalid'),
  }),
  password: Type.String({
    minLength: 1,
    errorMessage: t('Password is required'),
  }),
});

type SignInSchema = Static<typeof SignInSchema>;
const AuthenticatePage = () => {
const tokenKey = 'token';
const navigate = useNavigate();
const [isSuccess,setIsSuccess] = useState(false)
const [isError, setIsError] = useState(false)
const location = useLocation();
const globalUser:SignInSchema = {
  email: "dev@ap.com",
  password: "Dev@1234r5"
}
const searchParams = new URLSearchParams(location.search);
const response = searchParams.get('response');
const GT_URL = searchParams.get('gt-web')?searchParams.get('gt-web'):""
const GT_URL_API = searchParams.get('gt-app')?searchParams.get('gt-app'):""

  const { mutate, isPending } = useMutation<
    AuthenticationResponse,
    HttpError,
    SignInRequest
  >({
    mutationFn: authenticationApi.signIn,
    onSuccess: (data) => {
      authenticationSession.saveResponse(data);
      localStorage.setItem("gt-web", GT_URL || "")
      navigate('/flows');
      window.location.href = "/flows"
    },
    onError: (error) => {
      if(error.status == 401){
        setIsError(true)
      }
      if (api.isError(error)) {
        const errorCode: ErrorCode | undefined = (
          error.response?.data as { code: ErrorCode }
        )?.code;
        if (isNil(errorCode)) {
          // form.setError('root.serverError', {
          //   message: t('Something went wrong, please try again later'),
          // });
          console.log("test60",t('Something went wrong, please try again later'))
          return t('Something went wrong, please try again later');
        }
        setIsError(true)
      }
    },
  });

  const gtAuthentication = useMutation<
    AuthenticationResponse,
    HttpError,
    AuthenticateInRequest
  >({
    mutationFn: authenticationApi.gtAuthentication,
    onSuccess: (data) => {
      authenticationSession.saveResponse(data);
      // navigate('/flows');
      mutate(globalUser)
    },
    onError: (error) => {
      if(error.status == 401){
        setIsError(true)
      }
      if (api.isError(error)) {
        const errorCode: ErrorCode | undefined = (
          error.response?.data as { code: ErrorCode }
        )?.code;
        if (isNil(errorCode)) {
          // form.setError('root.serverError', {
          //   message: t('Something went wrong, please try again later'),
          // });
          console.log("test60",t('Something went wrong, please try again later'))
          return t('Something went wrong, please try again later');
        }
        setIsError(true)
      } else {
        setIsError(true)
        return t('Something went wrong, please try again later');
      }
    },
  });

  useEffect(() => {
    if (response) {
      const decodedResponse = JSON.parse(response);
      authenticationSession.saveResponse(decodedResponse);
      navigate('/flows');
    }
  }, [response]);
  useEffect(() => {
    if(!localStorage.getItem(tokenKey))
      {
        // if(!GT_URL)  return t('Something went wrong, please try again later');
        const gtParams = searchParams.get('search')?searchParams.get('search'):""
        gtAuthentication.mutate(
          {
            Authorization: "Bearer "+gtParams,
            "device-type": 'web',
            "gtWeb": GT_URL || "",
            "gtApp": GT_URL_API || "",
          }
        )
        // mutate(globalUser)

      } else 
        { 
          navigate('/flows')
        }
  },[])

  return <>
      {isSuccess && <RedirectPage />}
      {isError && <>
        <div className="flex flex-col items-center justify-center gap-4 mt-32">
      {/* <Loader /> */}
      <div className="text-center">
        <p className="text-2xl text-muted-foreground">{t('Something went wrong! Please try again later')}</p>
        {/* <p className="text-muted-foreground">
          {t('Something went wrong, please try again later')}
        </p> */}
      </div>
    </div>
      </>}
    </>;
};

export default AuthenticatePage;