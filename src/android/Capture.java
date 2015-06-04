/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
 */
package org.apache.cordova.mediacapture;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.text.SimpleDateFormat;
import java.util.Date;

import android.os.Build;

import org.apache.cordova.file.FileUtils;
import org.apache.cordova.file.LocalFilesystemURL;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginManager;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

//import com.simpleevent.xattender.R.string;

import android.app.Activity;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnPreparedListener;
import android.media.ThumbnailUtils;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Log;
import android.widget.ImageView;

public class Capture extends CordovaPlugin {

	private static final String VIDEO_3GPP = "video/3gpp";
	private static final String VIDEO_MP4 = "video/mp4";
	private static final String AUDIO_3GPP = "audio/3gpp";
	private static final String IMAGE_JPEG = "image/jpeg";

	private static final int CAPTURE_AUDIO = 0; // Constant for capture audio
	private static final int CAPTURE_IMAGE = 1; // Constant for capture image
	private static final int CAPTURE_VIDEO = 2; // Constant for capture video
	private static final String LOG_TAG = "Capture";

	private static final int CAPTURE_INTERNAL_ERR = 0;
	// private static final int CAPTURE_APPLICATION_BUSY = 1;
	// private static final int CAPTURE_INVALID_ARGUMENT = 2;
	private static final int CAPTURE_NO_MEDIA_FILES = 3;

	private CallbackContext callbackContext; // The callback context from which
												// we were invoked.
	private long limit; // the number of pics/vids/clips to take
	private int duration; // optional max duration of video recording in seconds
	private JSONArray results; // The array of results to be returned to the
								// user
	private int numPics; // Number of pictures before capture activity
	
	private String cur_fileName="";

	// private CordovaInterface cordova;

	// public void setContext(Context mCtx)
	// {
	// if (CordovaInterface.class.isInstance(mCtx))
	// cordova = (CordovaInterface) mCtx;
	// else
	// LOG.d(LOG_TAG,
	// "ERROR: You must use the CordovaInterface for this to work correctly. Please implement it in your activity");
	// }

	@Override
	public boolean execute(String action, JSONArray args,
			CallbackContext callbackContext) throws JSONException {
		this.callbackContext = callbackContext;
		this.limit = 1;
		this.duration = 0;
		this.results = new JSONArray();

		JSONObject options = args.optJSONObject(0);
		if (options != null) {
			limit = options.optLong("limit", 1);
			duration = options.optInt("duration", 0);
		}

		if (action.equals("getFormatData")) {
			JSONObject obj = getFormatData(args.getString(0), args.getString(1));
			callbackContext.success(obj);
			return true;
		} else if (action.equals("captureAudio")) {
			this.captureAudio();
		} else if (action.equals("captureImage")) {
			this.captureImage();
		} else if (action.equals("captureVideo")) {
			this.captureVideo(duration);
		} else {
			return false;
		}

		return true;
	}

	/**
	 * Provides the media data file data depending on it's mime type
	 *
	 * @param filePath
	 *            path to the file
	 * @param mimeType
	 *            of the file
	 * @return a MediaFileData object
	 */
	private JSONObject getFormatData(String filePath, String mimeType)
			throws JSONException {
		Uri fileUrl = filePath.startsWith("file:") ? Uri.parse(filePath) : Uri
				.fromFile(new File(filePath));
		JSONObject obj = new JSONObject();
		// setup defaults
		obj.put("height", 0);
		obj.put("width", 0);
		obj.put("bitrate", 0);
		obj.put("duration", 0);
		obj.put("codecs", "");

		// If the mimeType isn't set the rest will fail
		// so let's see if we can determine it.
		if (mimeType == null || mimeType.equals("") || "null".equals(mimeType)) {
			mimeType = FileHelper.getMimeType(fileUrl, cordova);
		}
		Log.d(LOG_TAG, "Mime type = " + mimeType);

		if (mimeType.equals(IMAGE_JPEG) || filePath.endsWith(".jpg")) {
			obj = getImageData(fileUrl, obj);
		} else if (mimeType.endsWith(AUDIO_3GPP)) {
			obj = getAudioVideoData(filePath, obj, false);
		} else if (mimeType.equals(VIDEO_3GPP) || mimeType.equals(VIDEO_MP4)) {
			obj = getAudioVideoData(filePath, obj, true);
		}
		return obj;
	}

	/**
	 * Get the Image specific attributes
	 *
	 * @param filePath
	 *            path to the file
	 * @param obj
	 *            represents the Media File Data
	 * @return a JSONObject that represents the Media File Data
	 * @throws JSONException
	 */
	private JSONObject getImageData(Uri fileUrl, JSONObject obj)
			throws JSONException {
		BitmapFactory.Options options = new BitmapFactory.Options();
		options.inJustDecodeBounds = true;
		BitmapFactory.decodeFile(fileUrl.getPath(), options);
		obj.put("height", options.outHeight);
		obj.put("width", options.outWidth);
		return obj;
	}

	/**
	 * Get the Image specific attributes
	 *
	 * @param filePath
	 *            path to the file
	 * @param obj
	 *            represents the Media File Data
	 * @param video
	 *            if true get video attributes as well
	 * @return a JSONObject that represents the Media File Data
	 * @throws JSONException
	 */
	private JSONObject getAudioVideoData(String filePath, JSONObject obj,
			boolean video) throws JSONException {
		MediaPlayer player = new MediaPlayer();
		try {
			player.setDataSource(filePath);
			player.prepare();
			obj.put("duration", player.getDuration() / 1000);
			if (video) {
				obj.put("height", player.getVideoHeight());
				obj.put("width", player.getVideoWidth());
			}
		} catch (IOException e) {
			Log.d(LOG_TAG, "Error: loading video file");
		}
		return obj;
	}

	/**
	 * Sets up an intent to capture audio. Result handled by onActivityResult()
	 */
	private void captureAudio() {
		Intent intent = new Intent(
				android.provider.MediaStore.Audio.Media.RECORD_SOUND_ACTION);

		this.cordova.startActivityForResult((CordovaPlugin) this, intent,
				CAPTURE_AUDIO);
	}

	private String getTempDirectoryPath() {
		File cache = null;

		// Use internal storage
		cache = cordova.getActivity().getCacheDir();

		// Create the cache directory if it doesn't exist
		cache.mkdirs();
		return cache.getAbsolutePath();
	}

	
	/**
	 * Sets up an intent to capture images. Result handled by onActivityResult()
	 */
	private void captureImage() {
		// Save the number of images currently on disk for later
		this.numPics = queryImgDB(whichContentStore()).getCount();

		Intent intent = new Intent(
				android.provider.MediaStore.ACTION_IMAGE_CAPTURE);

		// Specify file so that large image is captured and returned
		
		String imageName = getStringDate();
		cur_fileName = imageName;
		File photo = new File(getTempDirectoryPath(), "Capture.jpg");
		//File photo = new File(getTempDirectoryPath(), cur_fileName+".jpg");
		try {
			// the ACTION_IMAGE_CAPTURE is run under different credentials and
			// has to be granted write permissions
			createWritableFile(photo);
		} catch (IOException ex) {
			this.fail(createErrorObject(CAPTURE_INTERNAL_ERR, ex.toString()));
			return;
		}
		intent.putExtra(android.provider.MediaStore.EXTRA_OUTPUT,
				Uri.fromFile(photo));

		this.cordova.startActivityForResult((CordovaPlugin) this, intent,
				CAPTURE_IMAGE);
	}

	private static void createWritableFile(File file) throws IOException {
		file.createNewFile();
		file.setWritable(true, false);
	}

	/**
	 * Sets up an intent to capture video. Result handled by onActivityResult()
	 */
	private void captureVideo(int duration) {
		Intent intent = new Intent(
				android.provider.MediaStore.ACTION_VIDEO_CAPTURE);

		if (Build.VERSION.SDK_INT > 7) {
			intent.putExtra("android.intent.extra.durationLimit", duration);
		}
		this.cordova.startActivityForResult((CordovaPlugin) this, intent,
				CAPTURE_VIDEO);
	}

	
	
	/**
	  * 获取现在时间
	  * 
	  * @return返回字符串格式 yyyy-MM-dd HH:mm:ss
	  */
	public static String getStringDate() {
	  Date currentTime = new Date();
	  //SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
	  SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMddHHmmss");
	  String dateString = formatter.format(currentTime);
	  return dateString;
	}
	
	
	/**
	 * Called when the video view exits.
	 *
	 * @param requestCode
	 *            The request code originally supplied to
	 *            startActivityForResult(), allowing you to identify who this
	 *            result came from.
	 * @param resultCode
	 *            The integer result code returned by the child activity through
	 *            its setResult().
	 * @param intent
	 *            An Intent, which can return result data to the caller (various
	 *            data can be attached to Intent "extras").
	 * @throws JSONException
	 */
	public void onActivityResult(int requestCode, int resultCode,
			final Intent intent) {

		// Result received okay
		if (resultCode == Activity.RESULT_OK) {
			// An audio clip was requested
			if (requestCode == CAPTURE_AUDIO) {

				final Capture that = this;
				Runnable captureAudio = new Runnable() {

					@Override
					public void run() {
						// Get the uri of the audio clip
						Uri data = intent.getData();
						// create a file object from the uri
						results.put(createMediaFile(data));

						if (results.length() >= limit) {
							// Send Uri back to JavaScript for listening to
							// audio
							that.callbackContext
									.sendPluginResult(new PluginResult(
											PluginResult.Status.OK, results));
						} else {
							// still need to capture more audio clips
							captureAudio();
						}
					}
				};
				this.cordova.getThreadPool().execute(captureAudio);
			} else if (requestCode == CAPTURE_IMAGE) {
				// For some reason if I try to do:
				// Uri data = intent.getData();
				// It crashes in the emulator and on my phone with a null
				// pointer exception
				// To work around it I had to grab the code from
				// CameraLauncher.java

				final Capture that = this;
				Runnable captureImage = new Runnable() {
					@Override
					public void run() {
						try {
							// TODO Auto-generated method stub
							// Create entry in media store for image
							// (Don't use insertImage() because it uses default
							// compression setting of 50 - no way to change it)
							ContentValues values = new ContentValues();
							values.put(
									android.provider.MediaStore.Images.Media.MIME_TYPE,IMAGE_JPEG);
							Uri uri = null;
							try {
								uri = that.cordova
										.getActivity()
										.getContentResolver()
										.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
												values);
							} catch (UnsupportedOperationException e) {
								LOG.d(LOG_TAG,
										"Can't write to external media storage.");
								try {
									uri = that.cordova
											.getActivity()
											.getContentResolver()
											.insert(android.provider.MediaStore.Images.Media.INTERNAL_CONTENT_URI,
													values);
								} catch (UnsupportedOperationException ex) {
									LOG.d(LOG_TAG,
											"Can't write to internal media storage.");
									that.fail(createErrorObject(
											CAPTURE_INTERNAL_ERR,
											"Error capturing image - no media storage found."));
									return;
								}
							}
							
							FileInputStream fis = new FileInputStream(getTempDirectoryPath() + "/Capture.jpg");
							//FileInputStream fis = new FileInputStream(getTempDirectoryPath() + "/"+cur_fileName+".jpg");

							OutputStream os = that.cordova.getActivity().getContentResolver().openOutputStream(uri);
							byte[] buffer = new byte[4096];
							int len;
							while ((len = fis.read(buffer)) != -1) {
								os.write(buffer, 0, len);
							}
							os.flush();
							os.close();
							fis.close();

							// Add image to results
							results.put(createMediaFile(uri));

							//暂时注释,图片存缩略图会把原图给冲掉
							//checkForDuplicateImage();

							if (results.length() >= limit) {
								// Send Uri back to JavaScript for viewing image
								that.callbackContext
										.sendPluginResult(new PluginResult(
												PluginResult.Status.OK, results));
							} else {
								// still need to capture more images
								captureImage();
							}
						} catch (IOException e) {
							e.printStackTrace();
							that.fail(createErrorObject(CAPTURE_INTERNAL_ERR,
									"Error capturing image."));
						}
					}
				};
				this.cordova.getThreadPool().execute(captureImage);
			} else if (requestCode == CAPTURE_VIDEO) {

				final Capture that = this;
				Runnable captureVideo = new Runnable() {

					@Override
					public void run() {

						Uri data = null;

						if (intent != null) {
							// Get the uri of the video clip
							data = intent.getData();
						}

						if (data == null) {
							File movie = new File(getTempDirectoryPath(),
									"Capture.avi");
							data = Uri.fromFile(movie);
						}

						// create a file object from the uri
						if (data == null) {
							that.fail(createErrorObject(CAPTURE_NO_MEDIA_FILES,
									"Error: data is null"));
						} else {
							results.put(createMediaFile(data));

							if (results.length() >= limit) {
								// Send Uri back to JavaScript for viewing video
								that.callbackContext
										.sendPluginResult(new PluginResult(
												PluginResult.Status.OK, results));
							} else {
								// still need to capture more video clips
								captureVideo(duration);
							}
						}
					}
				};
				this.cordova.getThreadPool().execute(captureVideo);
			}
		}
		// If canceled
		else if (resultCode == Activity.RESULT_CANCELED) {
			// If we have partial results send them back to the user
			if (results.length() > 0) {
				this.callbackContext.sendPluginResult(new PluginResult(
						PluginResult.Status.OK, results));
			}
			// user canceled the action
			else {
				this.fail(createErrorObject(CAPTURE_NO_MEDIA_FILES, "Canceled."));
			}
		}
		// If something else
		else {
			// If we have partial results send them back to the user
			if (results.length() > 0) {
				this.callbackContext.sendPluginResult(new PluginResult(
						PluginResult.Status.OK, results));
			}
			// something bad happened
			else {
				this.fail(createErrorObject(CAPTURE_NO_MEDIA_FILES,
						"Did not complete!"));
			}
		}
	}

	/**
	 * Creates a JSONObject that represents a File from the Uri
	 *
	 * @param data
	 *            the Uri of the audio/image/video
	 * @return a JSONObject that represents a File
	 * @throws IOException
	 */
	private JSONObject createMediaFile(Uri data) {
		File fp = webView.getResourceApi().mapUriToFile(data);
		JSONObject obj = new JSONObject();

		Class webViewClass = webView.getClass();
		PluginManager pm = null;
		try {
			Method gpm = webViewClass.getMethod("getPluginManager");
			pm = (PluginManager) gpm.invoke(webView);
		} catch (NoSuchMethodException e) {
		} catch (IllegalAccessException e) {
		} catch (InvocationTargetException e) {
		}
		if (pm == null) {
			try {
				Field pmf = webViewClass.getField("pluginManager");
				pm = (PluginManager) pmf.get(webView);
			} catch (NoSuchFieldException e) {
			} catch (IllegalAccessException e) {
			}
		}
		FileUtils filePlugin = (FileUtils) pm.getPlugin("File");
		LocalFilesystemURL url = filePlugin.filesystemURLforLocalPath(fp
				.getAbsolutePath());

		try {
			// File properties
			obj.put("name", fp.getName());
			obj.put("fullPath", fp.toURI().toString());
			if (url != null) {
				obj.put("localURL", url.toString());
			}
			// Because of an issue with MimeTypeMap.getMimeTypeFromExtension()
			// all .3gpp files
			// are reported as video/3gpp. I'm doing this hacky check of the URI
			// to see if it
			// is stored in the audio or video content store.
			if (fp.getAbsoluteFile().toString().endsWith(".3gp")
					|| fp.getAbsoluteFile().toString().endsWith(".3gpp")) {

				if (data.toString().contains("/audio/")) {
					obj.put("type", AUDIO_3GPP);

				} else {
					obj.put("type", VIDEO_3GPP);

				}
			} else {
				obj.put("type",
						FileHelper.getMimeType(Uri.fromFile(fp), cordova));
			}

			obj.put("lastModifiedDate", fp.lastModified());
			obj.put("size", fp.length());

			if (data.toString().contains("/audio/")
					|| data.toString().contains("/video/")) {
				// 获取多媒体时长
				final MediaPlayer player = new MediaPlayer();
				try {
					player.setDataSource(fp.getPath().toString());
					player.prepare();

					int size = player.getDuration();
					//String timelong = size / 1000 + "s";
					String timelong = (size / 1000)+"";

					obj.put("fileDuration", timelong);
					Log.e("多媒体时长>>>>> ", timelong);

				} catch (IllegalArgumentException e) {
					e.printStackTrace();
				} catch (SecurityException e) {
					e.printStackTrace();
				} catch (IllegalStateException e) {
					e.printStackTrace();
				} catch (IOException e) {
					e.printStackTrace();
				}
				player.setOnPreparedListener(new OnPreparedListener() {

					@Override
					public void onPrepared(MediaPlayer mp) {
						// TODO Auto-generated method stub
						int size = player.getDuration();
						String timelong = size / 1000 + "s";

						Log.e("多媒体时长>>>>> ", timelong);
					}
				});
			}else {
				obj.put("fileDuration", "0");
			}
		    obj.put("fileThumbnailPath", "");
			if (data.toString().contains("/video/")) {
				 ImageView videoThumbnail = null;  
//				  imageThumbnail = (ImageView) findViewById(R.id.image_thumbnail);  
//			        videoThumbnail = (ImageView) findViewById(R.id.video_thumbnail);  
				  Bitmap videoBitmap = getVideoThumbnail(fp.getPath().toString(), 300, 300, MediaStore.Images.Thumbnails.MINI_KIND);
				    //Log.d("videoBitmap  >>> ", videoBitmap.toString());
			        //videoThumbnail.setImageBitmap(getVideoThumbnail(fp.getPath().toString(), 100, 100, MediaStore.Images.Thumbnails.MICRO_KIND));  
				    String  thumPath = saveThumbnail(videoBitmap);
				    obj.put("fileThumbnailPath", thumPath);
				    Log.d("thumPath >>>> ", thumPath);
			}
			
			if (data.toString().contains("images")) {
				 ImageView videoThumbnail = null;  
//				  imageThumbnail = (ImageView) findViewById(R.id.image_thumbnail);  
//			        videoThumbnail = (ImageView) findViewById(R.id.video_thumbnail);  
				  Bitmap imageThumbnail = getImageThumbnail(fp.getPath().toString(), 300, 300);
				    //Log.d("videoBitmap  >>> ", videoBitmap.toString());
			        //videoThumbnail.setImageBitmap(getVideoThumbnail(fp.getPath().toString(), 100, 100, MediaStore.Images.Thumbnails.MICRO_KIND));  
				    String  thumPath = saveThumbnail(imageThumbnail);
				    obj.put("fileThumbnailPath", thumPath);
				    Log.d("thumPath >>>> ", thumPath);
			}
			
//			if (data.toString().contains("/video/")) {
//				  ImageView imageThumbnail = null;  
//				  Bitmap imgBitmap = getImageThumbnail(fp.getPath().toString(), 100, 100);
//			        imageThumbnail.setImageBitmap(getImageThumbnail(fp.getPath().toString(), 100, 100));  
//
//			}
			
			 

		} catch (JSONException e) {
			// this will never happen
			e.printStackTrace();
		}
		return obj;
	}
	
	
	private String saveThumbnail(Bitmap bitmap)
	{
		 //Bitmap bitmap = (Bitmap) bundle.get("data");// 获取相机返回的数据，并转换为Bitmap图片格式
         FileOutputStream os = null;
         
         //照片的命名，目标文件夹下，以当前时间数字串为名称，即可确保每张照片名称不相同。网上流传的其他Demo这里的照片名称都写死了，则会发生无论拍照多少张，后一张总会把前一张照片覆盖。细心的同学还可以设置这个字符串，比如加上“ＩＭＧ”字样等；
         //然后就会发现ｓｄ卡中ｍｙｉｍａｇｅ这个文件夹下，会保存刚刚调用相机拍出来的照片，照片名称不会重复。
         String str=null;
         Date date=null;
         SimpleDateFormat format = new SimpleDateFormat("yyyyMMddHHmmss");//获取当前时间，进一步转化为字符串
         date =new Date();
         str=format.format(date);
         //String fileName = "/sdcard/myImage/"+str+".jpg";
         String fileName = str+".jpg";
//     	String imageName = getStringDate();
//		cur_fileName = imageName;
         //FileInputStream fis = new FileInputStream(getTempDirectoryPath() + "/Capture.jpg");
 		 File photo = new File(getTempDirectoryPath(), fileName);
 		 //new File(dir, name)
         //File file = new File("/sdcard/myImage/");
         //file.mkdirs();// 创建文件夹，名称为myimage
 		 
			final Capture that = this;

 		ContentValues values = new ContentValues();
		values.put(
				android.provider.MediaStore.Images.Media.MIME_TYPE,IMAGE_JPEG);
		Uri uri = null;
		try {
			uri = that.cordova
					.getActivity()
					.getContentResolver()
					.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
							values);
		} catch (UnsupportedOperationException e) {
			LOG.d(LOG_TAG,
					"Can't write to external media storage.");
			try {
				uri = that.cordova
						.getActivity()
						.getContentResolver()
						.insert(android.provider.MediaStore.Images.Media.INTERNAL_CONTENT_URI,
								values);
			} catch (UnsupportedOperationException ex) {
				LOG.d(LOG_TAG,
						"Can't write to internal media storage.");
				that.fail(createErrorObject(
						CAPTURE_INTERNAL_ERR,
						"Error capturing image - no media storage found."));
				return "";
			}
		}
		try {
			OutputStream oos = that.cordova.getActivity().getContentResolver().openOutputStream(uri);
			
			bitmap.compress(Bitmap.CompressFormat.JPEG, 100, oos);// 把数据写入文件
			
			File fp = webView.getResourceApi().mapUriToFile(uri);

	        String   imgPath =  fp.getPath();
	             
	        return  imgPath;
			
		} catch (FileNotFoundException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
       
//        try {
//        	 os = new FileOutputStream(photo.getPath().toString());
//             bitmap.compress(Bitmap.CompressFormat.JPEG, 100, os);// 把数据写入文件
//             String   imgPath =  photo.getPath();
//             return  imgPath;
//             
//         } catch (FileNotFoundException e) {
//             e.printStackTrace();
//         } finally {
//             try {
//            	 os.flush();
//            	 os.close();
//             } catch (IOException e) {
//                 e.printStackTrace();
//             }
//         }
        //String   imgPath =  photo.getPath();
        return  "";

		
	}
	
	/** 
     * 根据指定的图像路径和大小来获取缩略图 
     * 此方法有两点好处： 
     *     1. 使用较小的内存空间，第一次获取的bitmap实际上为null，只是为了读取宽度和高度， 
     *        第二次读取的bitmap是根据比例压缩过的图像，第三次读取的bitmap是所要的缩略图。 
     *     2. 缩略图对于原图像来讲没有拉伸，这里使用了2.2版本的新工具ThumbnailUtils，使 
     *        用这个工具生成的图像不会被拉伸。 
     * @param imagePath 图像的路径 
     * @param width 指定输出图像的宽度 
     * @param height 指定输出图像的高度 
     * @return 生成的缩略图 
     */  
    private Bitmap getImageThumbnail(String imagePath, int width, int height) {  
        Bitmap bitmap = null;  
        BitmapFactory.Options options = new BitmapFactory.Options();  
        options.inJustDecodeBounds = true;  
        // 获取这个图片的宽和高，注意此处的bitmap为null  
        bitmap = BitmapFactory.decodeFile(imagePath, options);  
        options.inJustDecodeBounds = false; // 设为 false  
        // 计算缩放比  
        int h = options.outHeight;  
        int w = options.outWidth;  
        int beWidth = w / width;  
        int beHeight = h / height;  
        int be = 1;  
        if (beWidth < beHeight) {  
            be = beWidth;  
        } else {  
            be = beHeight;  
        }  
        if (be <= 0) {  
            be = 1;  
        }  
        options.inSampleSize = be;  
        // 重新读入图片，读取缩放后的bitmap，注意这次要把options.inJustDecodeBounds 设为 false  
        bitmap = BitmapFactory.decodeFile(imagePath, options);  
        // 利用ThumbnailUtils来创建缩略图，这里要指定要缩放哪个Bitmap对象  
		bitmap = ThumbnailUtils.extractThumbnail(bitmap, width, height,  
                ThumbnailUtils.OPTIONS_RECYCLE_INPUT);  
        return bitmap;  
    }  
  
    /** 
     * 获取视频的缩略图 
     * 先通过ThumbnailUtils来创建一个视频的缩略图，然后再利用ThumbnailUtils来生成指定大小的缩略图。 
     * 如果想要的缩略图的宽和高都小于MICRO_KIND，则类型要使用MICRO_KIND作为kind的值，这样会节省内存。 
     * @param videoPath 视频的路径 
     * @param width 指定输出视频缩略图的宽度 
     * @param height 指定输出视频缩略图的高度度 
     * @param kind 参照MediaStore.Images.Thumbnails类中的常量MINI_KIND和MICRO_KIND。 
     *            其中，MINI_KIND: 512 x 384，MICRO_KIND: 96 x 96 
     * @return 指定大小的视频缩略图 
     */  
    private Bitmap getVideoThumbnail(String videoPath, int width, int height,  
            int kind) {  
        Bitmap bitmap = null;  
        // 获取视频的缩略图  
        bitmap = ThumbnailUtils.createVideoThumbnail(videoPath, kind);  
        System.out.println("w"+bitmap.getWidth());  
        System.out.println("h"+bitmap.getHeight());  
        bitmap = ThumbnailUtils.extractThumbnail(bitmap, width, height,  
                ThumbnailUtils.OPTIONS_RECYCLE_INPUT);  
        return bitmap;  
    }  
    
    

	private JSONObject createErrorObject(int code, String message) {
		JSONObject obj = new JSONObject();
		try {
			obj.put("code", code);
			obj.put("message", message);
		} catch (JSONException e) {
			// This will never happen
		}
		return obj;
	}

	/**
	 * Send error message to JavaScript.
	 *
	 * @param err
	 */
	public void fail(JSONObject err) {
		this.callbackContext.error(err);
	}

	/**
	 * Creates a cursor that can be used to determine how many images we have.
	 *
	 * @return a cursor
	 */
	private Cursor queryImgDB(Uri contentStore) {
		return this.cordova
				.getActivity()
				.getContentResolver()
				.query(contentStore,
						new String[] { MediaStore.Images.Media._ID }, null,
						null, null);
	}

	/**
	 * Used to find out if we are in a situation where the Camera Intent adds to
	 * images to the content store.
	 */
	private void checkForDuplicateImage() {
		Uri contentStore = whichContentStore();
		Cursor cursor = queryImgDB(contentStore);
		int currentNumOfImages = cursor.getCount();

		// delete the duplicate file if the difference is 2
		if ((currentNumOfImages - numPics) == 2) {
			cursor.moveToLast();
			int id = Integer.valueOf(cursor.getString(cursor
					.getColumnIndex(MediaStore.Images.Media._ID))) - 1;
			Uri uri = Uri.parse(contentStore + "/" + id);
			this.cordova.getActivity().getContentResolver().delete(uri, null, null);
		}
	}

	/**
	 * Determine if we are storing the images in internal or external storage
	 * 
	 * @return Uri
	 */
	private Uri whichContentStore() {
		if (Environment.getExternalStorageState().equals(
				Environment.MEDIA_MOUNTED)) {
			return android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
		} else {
			return android.provider.MediaStore.Images.Media.INTERNAL_CONTENT_URI;
		}
	}
}
